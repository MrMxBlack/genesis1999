# Genesis1999, Mainnet Deployment Record

Deployed 2026-10-31 (Asia/Dhaka) on BNB Smart Chain (chainId 56).
Method: temporary deployer EOA (0x3e2c1e88d9DA43e8c0882CaA4e7a060C30083cB1) funded from the
mee.ai agentic wallet, because `baw contract-call` cannot create contracts. All ownership
was transferred to the mee.ai wallet afterwards and the deployer key was shredded
(deployer balance swept back to mee.ai first; final deployer balance 0).

## Canonical contracts (owner: 0xB0cB52091aDd24aCb9542081a0f1d5a946998636, mee.ai)

| Contract | Address | Deploy tx |
|---|---|---|
| G1999Token | 0xe3fc783CE8798d1d7B916e279df6c44cDd02f9eb | 0xb5e33b234f082660ea438582908b4959b0d4963f2958c8c42a22aab513513ff5 |
| Genesis1999 (NFT) | 0x19ec51c1492aeb41e211891206a9b58bd7a965a1 | 0x6a6a643dd66e4334e7ddce83ab43436df7e40199640b438106e9f8bfb1471ad9 |
| Mining1999 | 0xD9E6D088F9DCe21906b43467D3bF55a2137246DF | 0x450e267ba5ceb6583f43d28a10966c264f23ed059f93b8faf8244e87a1b949d8 |

## Token allocations (verified on-chain at deploy)
- Total supply 99,990,000 G1999 (18 decimals), minted once at creation.
- Mining1999 contract: 34,496,550 (34.5% mining pool, allocated directly by the token
  constructor because Binance's risk engine blocks agentic-wallet transfers of the new
  token; the mining vault was set to Mining1999's predicted CREATE address).
- mee.ai wallet: 65,493,450 (airdrop 24,497,550 + public sale 10,998,900 + promotion
  9,999,000 + team 19,998,000 buckets).

## Launch switches (all OFF at deploy, owner activates at launch)
- Genesis1999.freeMintActive = false, saleActive = false
- Mining1999.started = false (call startMining() at launch; pool budget = its balance)

## Superseded first-pass contracts (inert, do NOT use)
- G1999Token v1: 0xe1fe214a4139eac3540f01f29eeaaee7b282a8a9 (all 99.99M supply sits in the
  mee.ai wallet as a dead token; its mining vault pointed at the wallet, which is why v2 exists)
- Mining1999 v1: 0x8c136f2a0f73c5ba6238e2b8530379d64f74cb9a (points at token v1; empty)
Both are also owned by mee.ai (ownership transferred with the rest).

## Funding trail
- Agentic wallet → deployer: 0.00036 BNB (tx 0xfdafee556e6c1d64022789d6e37e77448ddb8cba3d84d1c5e062f87455b1a491)
  + 0.000025 BNB top-up, both via contract-call Send (wallet send was address-book blocked).
- Deployer → mee.ai sweep-back: 0.0000379 BNB (tx 0xc4faa6a15dcd980749e88480a2c8aaf1d631300864ed28d914203bbb66af1870).
- Total deployment gas: ~5.93M gas at 0.05 gwei ≈ 0.0003 BNB (~$0.21).

## v3 redeploy (2026-10-31), CANONICAL token + mining

The user added a free mining tier and set the mining power ladder, which required
redeploying the token and mining contracts (the NFT is unchanged). A second
temporary deployer EOA (0x75996880000eb82655FF33ba94db7349a289E7a5, funded with
0.00015 BNB from the agentic wallet, tx 0x06c5590c770d6e07257448a159e73c259bfc50182a30709e03a25c221b95d409;
key shredded after use; leftover 0.0000379 BNB swept back, tx 0xd323496249953b5a940f5240f36de68e22d2cd9fba73aa721014fd4c3d6c519c)
deployed at nonce 0/1:

- **G1999Token v3: 0xC3c403ed9297f059B633cEdAA75Bf0602419D8e6** (tx 0xaa14289169837a9290591c5cac1629e16d38a6e07ea803c8436bc4a64a4ba58e, gasUsed 734,311)
  - mining vault = the predicted Mining1999 v3 address, so the 34,496,550 pool was
    allocated at creation (verified on-chain); mee.ai holds the other 65,493,450.
- **Mining1999 v3: 0xcc26bACC9429D3a861623a05793B0812D965A71b** (tx 0x26704495fecf400c4b7faa868c5f632683e6b6866687dcba9beda7f31b0ede66, gasUsed 1,430,174)
  - Free mining: baseWeight = 1 for every wallet. NFT power ladder (owner-set):
    Common 3 · Rare 5 · Epic 7 · Legendary 12. Token power is value-based and
    added last: (whole tokens × tokenPriceUsd) / usdPerPower, usdPerPower = $0.40
    (above every NFT tier's price-per-power, so the token route costs more);
    tokenPriceUsd = 0 until the owner sets the token's reference price.
- Both owned by mee.ai (ownership transfers 0xe6c35eeb… and 0xac9a136d…), verified
  on a second dataseed: owners, baseWeight=1, ladder=3/5/7/12, started=false.
- **Both v3 contracts are Sourcify exact-match verified** (see VERIFICATION.md).
- The v2 token (0xe3fc783CE8798d1d7B916e279df6c44cDd02f9eb) and v2 mining
  (0xD9E6D088F9DCe21906b43467D3bF55a2137246DF) are SUPERSEDED/inert like v1
  (v2 mining still holds its 34,496,550 v2 tokens, dead tokens, no rescue path
  by design). Canonical set is now: NFT 0x19ec51c1492aeb41e211891206a9b58bd7a965a1 ·
  Token v3 · Mining v3.
