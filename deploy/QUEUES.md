# Genesis1999 v4 — mint queues: method & verification

The v4 NFT contract never invents a tier at mint time. Every tokenId's tier
is fixed by `metadata/<id>.json`, and mints draw tokenIds from precomputed,
tier-pure queues so on-chain `tierOf(id)` always equals the metadata tier.
This document records how `deploy/queues.json` is generated.

Generator: `scripts/generate-queues.mjs` — run `node scripts/generate-queues.mjs`.
It is deterministic: same metadata in, byte-identical `queues.json` out
(md5 `ad4a4cc089b8b2e0b786ed832d00a821` for the current metadata set).

## Method

1. **Read tiers.** For ids 1..1999 (ascending), read the tier from
   `metadata/<id>.json` (`attributes[0]`, the `Tier` attribute). Counts on
   disk: Common 1100 · Rare 450 · Epic 250 · Legendary 199.
2. **PRNG.** One `mulberry32` stream, **seed 1999** — the implementation is
   copied verbatim from `scripts/generate-metadata.mjs`. The stream is
   consumed in exactly this order:
   1. Fisher–Yates shuffle of each tier's id list (ascending before the
      shuffle), tiers in enum order Common → Rare → Epic → Legendary,
      using the same loop form as the metadata generator
      (`for i = n-1 … 1: j = floor(rng() * (i+1)); swap`).
   2. The combined free list (step 3) is shuffled once more.
3. **Slice.** Each tier's shuffled list is sliced in the order
   **[sale, team, mining (Legendary only), free = remainder]**:

   | Tier      | Sale | Team | Mining | Free | Total |
   |-----------|-----:|-----:|-------:|-----:|------:|
   | Common    |    – |    – |      – | 1100 |  1100 |
   | Rare      |   68 |   30 |      – |  352 |   450 |
   | Epic      |   75 |   25 |      – |  150 |   250 |
   | Legendary |  100 |   15 |     45 |   39 |   199 |

4. **Free queue.** The four free slices are concatenated
   (Common + Rare + Epic + Legendary) and shuffled once more with the same
   PRNG stream → `freeQueue` (1,641 ids, mixed tiers — the free-mint draw
   is uniform over these ids, so tier odds equal the remaining pool
   proportions, exactly as in the v3 gacha).

## Output: `deploy/queues.json`

Keys: `freeQueue` (1641), `saleRare` (68), `saleEpic` (75),
`saleLegendary` (100), `teamRare` (30), `teamEpic` (25),
`teamLegendary` (15), `miningQueue` (45), and `tiersById` — an array of
1,999 tier indices (0=Common, 1=Rare, 2=Epic, 3=Legendary) in id order
1..1999, used to build the contract's packed tier table.

## Verification (run by the generator itself, 2026-10-31)

```
freeQueue:      1641 (Common 1100 · Rare 352 · Epic 150 · Legendary 39)
sale queues:    Rare 68 · Epic 75 · Legendary 100
team queues:    Rare 30 · Epic 25 · Legendary 15
miningQueue:    45
total queued:   1999 (expected 1999)
VERIFICATION: PASS — every id 1..1999 appears exactly once, every queued id's metadata tier matches its bucket, all counts exact
```

Checks performed: every id 1..1999 appears **exactly once** across all
queues; every id in a tier-named queue has that metadata tier; the free
queue's per-tier composition is exactly 1100/352/150/39; `tiersById`
reproduces the metadata tier of every id and the 1100/450/250/199 counts.
The generator exits non-zero on any problem and writes nothing on failure.

Independently, `scripts/local-test.mjs` re-validates the same data
end-to-end on-chain: it drains a fresh contract's entire free queue and
asserts the minted id set equals `freeQueue` exactly, and checks
`tierOf(id)` against the metadata for every token minted in the suite
(and for all 1,999 ids pre-mint).

## How the queues reach the contract

Constructor args are packed LSB-first (element k occupies bits
`[k·bits, k·bits + bits)` of the byte stream):

- `queuesPacked`: the 8 queues concatenated in the order
  [free, saleRare, saleEpic, saleLegendary, teamRare, teamEpic,
  teamLegendary, mining], each tokenId at **11 bits** → 2,749 bytes.
- `tiersPacked`: `tiersById` at **2 bits** per id → 500 bytes.

See `deploy/V4-CHANGES.md` for the full constructor format.
