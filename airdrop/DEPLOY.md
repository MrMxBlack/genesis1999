# G1999 Airdrop — Merkle Claim Distributor

Paid-claim Merkle distributor for the Genesis1999 (G1999) holder airdrop.
Snapshot: the 1,756 minted Genesis1999 NFTs (user decisions 2026-11-04:
distribution over minted NFTs only, the reserve share is KEPT — the mee.ai
wallet is itself a claimant for its 115 reserve NFTs, and claims are PAID).

## Contract

- **G1999Airdrop:** `0xa483E8378CE6bCE5a9816Ad461e0B489758931bF` (BSC, chain 56)
- Token (G1999): `0xDb8911F5072ab679e2084A34b5D3cF39EbC96DD4`
- Owner: mee.ai wallet `0xB0cB52091aDd24aCb9542081a0f1d5a946998636`
- Treasury (claim fees): `0x36aB2cB68475CfDb4B7da0c33e20b4C1a1837486` (hardcoded constant)
- Chainlink BNB/USD feed: `0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE`
- **Merkle root:** `0xed38cd1756c8694eaa1427052fd31ba88411ddcd5a19cb7ca64cfb54ccf1e2ef`
- Claim deadline: 1825348224 (2027-11-04 17:10:24 UTC, deploy + 365 days);
  after it the owner can withdraw unclaimed tokens.
- Claims active: **NO** — the owner activates after the distributor is funded.
- Sourcify: **exact_match** (creation + runtime), matchId 58388916,
  verified 2026-11-04T17:11:02Z.

## Committed pool

- Wallets: 842 (see `claims.json` — public claim data by design)
- **Total committed: 24,497,549.99999999999999664 G1999**
  = 24497549999999999999996640 wei = pool 24,497,550 G1999 minus the
  3,360 wei of rounding dust recorded in the snapshot summary.
- Leaf scheme: `leaf = keccak256(abi.encodePacked(account, amountWei, feeUsdCents))`;
  pair hashing sorts each pair (OpenZeppelin MerkleProof convention).
- Source snapshot: `airdrop-2026-11-04.csv` / `airdrop-2026-11-04-summary.json`
  (tier weights Common 1 · Rare 3 · Epic 7 · Legendary 15 over 4,956 weight).

## Claim fees (paid claims)

Each claim charges a BNB fee priced in USD at the live Chainlink BNB/USD
rate, scaled by the tiers inside that wallet's allocation:

| Tier      | Fee per NFT |
|-----------|-------------|
| Common    | $0.03 (3¢)  |
| Rare      | $0.07 (7¢)  |
| Epic      | $0.11 (11¢) |
| Legendary | $0.15 (15¢) |

Per-wallet commitment: `feeUsdCents = 3*common + 7*rare + 11*epic + 15*legendary`,
committed inside the Merkle leaf (see `claims.json`). Conversion reuses the
Genesis1999 pattern (USD at 8 decimals): `feeBnb = (feeUsdCents * 1e24) / answer`.
The fee is forwarded to the treasury in the same transaction, any
overpayment is refunded in the same transaction, and the contract never
accumulates BNB (a failed fee forward reverts the claim).

**Total potential fee income if every wallet claims: 9,384 US cents = $93.84**
(1,100×3 + 382×7 + 175×11 + 99×15). Largest single fee: mee.ai itself,
1,385¢ ($13.85) for its 115 reserve NFTs.

## Deploy transactions (deployer 0x9990f1C4A660D7D95cE76280cb7a8a8B2f1D07b4, gas price 0.05 gwei)

| Step | Tx | Gas used |
|------|----|----------|
| Deploy | `0x495ad3d409d947c94b598ffd94ade104b5b0df59b58c5bd532f4e9cb105be246` | 914,527 |
| setRoot | `0xf746be4bda5665a48630bdfa859201f08c93f41b12357ce83d23b29a52e1eff8` | 49,296 |
| transferOwnership → mee.ai | `0x94f384ede961fbc1ebc63d576e99a85036b53526f752feee3ce98f0c788e11b8` | 28,592 |

Total gas spent: 992,415 gas = **0.00004962075 BNB**, paid from the presale
deployer EOA (balance before: 0.000254920 BNB). Final state verified on
bsc-dataseed1 + bsc-dataseed3: owner = mee.ai, root matches, token = G1999,
claimsActive = false, distributor G1999 balance = 0.
Local tests: 27/27 passed (ganache, MockERC20 + MockFeed $880, real root and
real claims via unlocked claimant accounts).

## Funding instruction (one manual step for the user)

Agent-initiated G1999 transfers from the mee.ai wallet are blocked by the
Binance risk engine (code 351803), so funding is manual, exactly like the
presale funding:

> **Send 24,497,550 G1999 from the mee.ai wallet in the Binance app to the distributor address 0xa483E8378CE6bCE5a9816Ad461e0B489758931bF**

(The tree commits 3,360 wei less than this round figure; the tiny excess
simply stays in the contract and is withdrawable by the owner after the
claim deadline.) After funding lands, the owner calls `activate()` on the
distributor and claims open.
