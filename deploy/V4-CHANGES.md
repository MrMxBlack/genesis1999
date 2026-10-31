# Genesis1999 NFT — v4 changes vs v3

**Why:** v3 (`contracts/Genesis1999.v3.sol`, backed up unchanged) assigned
each token the *next sequential id* and drew its *tier* at mint time from
pool counts. But `metadata/<id>.json` fixes every id's tier (and its art)
in advance. The two would disagree for most tokens — e.g. a buyer paying
the $4 Legendary price could receive Common artwork, and a Legendary-
looking NFT could carry Common mining/airdrop weight. v4 binds the
contract to the metadata: mints draw **tokenIds** from precomputed
tier-pure queues (`deploy/queues.json`, see `deploy/QUEUES.md`), and the
tier of an id is read from a packed tier table. `tierOf(id)` now equals
the metadata/art tier for every id, minted or not.

Nothing else in the system changed: `G1999Token.sol` and `Mining1999.sol`
are untouched (Mining only reads `tierBalances(address,uint8)`, whose
behaviour is unchanged), as are metadata, art and the site.

## What the contract does differently

- **No sequential ids, no tier draw.** A private `_draw(queue)` picks a
  random index into the queue's remaining slice (same `_random`
  block-data + nonce approach as v3), swap-and-pops it, and returns the
  id. Each id sits in exactly one queue and is popped at most once, so
  no id can ever mint twice, and total minted can reach exactly 1,999.
- **freeMint()** draws uniformly from the combined 1,641-id free queue.
  Uniform-over-ids makes the tier probability equal to the remaining
  per-tier proportions — the same odds as the v3 gacha (Legendary drop
  starts at 39/1641). The drawn id's tier comes from the tier table;
  per-tier free counters keep `freeRemaining(tier)` exact.
- **buy(tier)** draws from that tier's sale queue (the buyer always gets
  art of the tier they paid for). Payment, Chainlink USD pricing
  ($0.70/$2/$4) and the exact-refund logic are unchanged. An internal
  invariant re-checks the drawn id's table tier against the requested
  tier (`"queue tier mismatch"` — unreachable with the verified queues).
- **mintTeamReserve(to, tier) / mintMiningReserve(to)** draw from the
  team / mining queues the same way, with the same owner-only access and
  revert messages as v3.
- **Remaining counts** (`freeRemaining`, `saleRemaining`,
  `teamRemaining`, `miningRemaining`, `totalFreeRemaining`) are computed
  from the live queue lengths, so they are always consistent with what
  can still be minted.

## Public interface: preserved, with these mechanical differences

Everything else — ERC721 + ERC2981 (5% royalty), Ownable,
ReentrancyGuard, prices, `priceInBnb`, `maxFreePerWallet` (default 5),
`freeMintedBy`, `tierBalances` tracking in `_update`, the admin setters
(`setFreeMintActive` / `setSaleActive` / `setMaxFreePerWallet` /
`setBaseURI`), `withdraw`, `tokenURI`, `totalMinted`, and the
`FreeMint` / `Purchase` / `ReserveMint` events — is behaviour-identical
to v3.

- **Constructor** gains two parameters (below).
- `tierOf`, `freeRemaining`, `saleRemaining`, `teamRemaining`,
  `miningRemaining` were public state variables in v3 and are **view
  functions** in v4 — identical ABI signatures and selectors, identical
  values for all valid inputs. One deliberate improvement: v3's `tierOf`
  mapping returned Common for every unminted id; v4's `tierOf` returns
  the id's true metadata tier whether or not it is minted yet
  (out-of-range ids still return Common, matching the old default).

## Constructor arguments

```
constructor(
    string name_, string symbol_, address feed, address royaltyReceiver,
    bytes queuesPacked,   // 2,749 bytes
    bytes tiersPacked     // 500 bytes
)
```

Packing is LSB-first (element k occupies bits `[k·bits, k·bits+bits)`):

- `queuesPacked`: the 8 queues from `deploy/queues.json` concatenated in
  the order [free, saleRare, saleEpic, saleLegendary, teamRare, teamEpic,
  teamLegendary, mining] — initial lengths 1641 / 68 / 75 / 100 / 30 /
  25 / 15 / 45 — each tokenId at **11 bits** → 2,749 bytes total.
- `tiersPacked`: tier index (0..3) of ids 1..1999 in id order, at
  **2 bits** each → 500 bytes total.

On-chain they are stored as two `bytes` blobs plus one packed word of
queue lengths (11 bits each); draws read/write 11-bit elements in place
(swap-and-pop), and tier lookups read the 2-bit table. The constructor
only checks the two byte lengths — the queues themselves are verified
exhaustively off-chain by `scripts/generate-queues.mjs` and end-to-end
by `scripts/local-test.mjs`. The packing code used by the test (and
intended for the v4 deploy script) is `packBits()` in
`scripts/local-test.mjs`.

## Deploy gas (measured locally, ganache, Shanghai EVM)

| Version | NFT deploy gas |
|---------|---------------:|
| v3      | 2,620,651      |
| v4      | **5,202,716**  |

Under the 6M target with ~13% headroom. The difference is almost entirely
one-time storage initialisation: ~86 slots for the packed queue blob,
~16 for the tier table, plus the larger runtime (creation bytecode
13,346 bytes vs 11,363).

## Test-suite note (not a contract change)

`scripts/local-test.mjs` passes explicit gas limits on block-dependent
calls (mint draws, Mining `poke`/`claim`). Reason: `eth_estimateGas`
simulates against a different block than the tx mines in, and these
calls' costs depend on the block (blockhash-drawn storage patterns;
Mining's accrual path flips with the block timestamp), so raw estimates
intermittently undershot and produced status-0 reverts in the local
suite. With explicit limits the suite runs 100/100 green, and a
byte-for-byte JS mirror of the packed queue blob matched the chain after
every draw during diagnosis. On BSC the deploy tooling already sets gas
explicitly, so this does not affect deployment.
