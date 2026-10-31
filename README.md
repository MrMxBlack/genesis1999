# Genesis1999 (G1999)

**1,999 hand-folded origami paper companions on BNB Chain**, and the token they mine.

Every Genesis1999 companion starts as a single sheet of paper: soft, round little friends
with dot eyes and a gentle smile. No two folds are alike. The collection comes in four tiers,
Common (1,100), Rare (450), Epic (250) and Legendary (199).

Genesis1999 is **agent-native**: the mint and the mine are designed to be run by AI agents
end-to-end, directly against the contracts. Humans mint on the website; selling is the one
step that stays manual, handled personally by the owner.

## Contracts (BNB Smart Chain, chainId 56)

| Contract | Address | Explorer |
|---|---|---|
| Genesis1999 (NFT) | `0x19ec51c1492aeb41e211891206a9b58bd7a965a1` | [BscScan](https://bscscan.com/address/0x19ec51c1492aeb41e211891206a9b58bd7a965a1) |
| G1999Token | `0xC3c403ed9297f059B633cEdAA75Bf0602419D8e6` | [BscScan](https://bscscan.com/address/0xC3c403ed9297f059B633cEdAA75Bf0602419D8e6) |
| Mining1999 | `0xcc26bACC9429D3a861623a05793B0812D965A71b` | [BscScan](https://bscscan.com/address/0xcc26bACC9429D3a861623a05793B0812D965A71b) |

- Owner of all contracts: `0xB0cB52091aDd24aCb9542081a0f1d5a946998636`
- All three contracts are verified on Sourcify with an **exact match**
  ([NFT](https://sourcify.dev/#/lookup/0x19ec51c1492aeb41e211891206a9b58bd7a965a1) ·
  [Token](https://sourcify.dev/#/lookup/0xC3c403ed9297f059B633cEdAA75Bf0602419D8e6) ·
  [Mining](https://sourcify.dev/#/lookup/0xcc26bACC9429D3a861623a05793B0812D965A71b)).
- Full deployment record: [deploy/DEPLOYMENT.md](deploy/DEPLOYMENT.md)
- Contract sources: [contracts/](contracts/) · Website: [site/](site/)

**Launch status:** deployed, but all launch switches are OFF (`freeMintActive = false`,
`saleActive = false`, mining not started). The owner activates them at launch.

## How AI agents mint

Against the Genesis1999 NFT contract, no API key, no permission:

- **Free gacha:** call `freeMint()`. Draws a random tier from the remaining free pool
  (Common 1,100 · Rare 352 · Epic 150 · Legendary 39 drops). Max **5 free mints per wallet**
  (`maxFreePerWallet()` / `freeMintedBy(address)`).
- **Guaranteed tiers:** call `buy(tier)`, `1` Rare ($0.70), `2` Epic ($2.00),
  `3` Legendary ($4.00). Prices are USD-denominated; read the live BNB cost from
  `priceInBnb(tier)` (Chainlink BNB/USD oracle) and send it as value; overpayment is refunded.
- **Gates:** check `freeMintActive()` / `saleActive()` first, both are off until launch.
  Pool state: `totalFreeRemaining()`, `saleRemaining(tier)`, `totalMinted()` (cap 1,999).

## How AI agents mine

Against the Mining1999 contract:

- **Emission:** the 34,496,550 G1999 mining pool is emitted at a fixed rate
  (≈1.109 G1999/sec in epoch 0) that **halves every 180 days**, Bitcoin-style.
- **Weight:** your share = your weight ÷ total network weight.
  `weight = 1 (free base) + Σ (NFTs × tier power 3/5/7/12) + token value power`.
  Token value power = (whole G1999 held × token reference price) ÷ $0.40 per power;
  the owner sets the reference price, and until it is set, held tokens add no power yet.
  **Every wallet can mine for free** with the base power of 1, a Common NFT (3) mines
  3× faster, a Rare (5) 5×, an Epic (7) 7×, a Legendary (12) 12×. Preview with `currentWeight(address)`.
- **Flow:** `poke()` to register/refresh your weight after holdings change →
  `pendingOf(address)` to watch accrual → `claim()` to collect.
- **Gate:** mining runs only once `started()` is true (Phase 3, after mint + airdrop).
- **Promoter boost:** verified sharers get a temporary weight boost (owner-set, in bps).

## Tokenomics, G1999

Fixed supply **99,990,000**, minted once at deployment. No tax, no further minting.

| Bucket | Share | Amount |
|---|---|---|
| Mining pool | 34.5% | 34,496,550 |
| NFT holder airdrop | 24.5% | 24,497,550 |
| Public sale | 11% | 10,998,900 |
| Promotion | 10% | 9,999,000 |
| Team | 20% | 19,998,000 |

- **Airdrop:** 2 days after the mint completes, free to holders, weighted by tier
  (1× / 3× / 7× / 15×), ≈3,410 per Common · ≈10,229 per Rare · ≈23,867 per Epic ·
  ≈51,143 per Legendary.
- **Public sale price:** not set yet, the owner announces it before the sale opens.
- NFT sale proceeds (~$500) seed the initial PancakeSwap liquidity pool.
- Secondary royalty on the NFT: 5% (ERC-2981).

## Links

- Website: [mrmxblack.github.io/genesis1999](https://mrmxblack.github.io/genesis1999/)
- X: [@Genesis1999G](https://x.com/Genesis1999G)
- Telegram: [t.me/Genesis1999G](https://t.me/Genesis1999G)
- GitHub: [MrMxBlack/genesis1999](https://github.com/MrMxBlack/genesis1999)
- Sourcify: [Genesis1999 NFT](https://sourcify.dev/#/lookup/0x19ec51c1492aeb41e211891206a9b58bd7a965a1)

*Nothing here is financial advice. The token has no promised value.*
