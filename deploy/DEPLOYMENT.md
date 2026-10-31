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

## v4 redeploy (2026-10-31), CANONICAL — tier-queue fix

A pre-launch review found the flaw: metadata/art assign each tokenId a FIXED tier, but
the v3 NFT assigned tier randomly at mint, so chain tier (mining weight, airdrop) would
have mismatched the art. The v4 NFT draws tokenIds from precomputed queues bound to the
metadata tiers (deploy/queues.json, deploy/QUEUES.md, deploy/V4-CHANGES.md; local suite
100/100). Mining1999's immutable NFT pointer and the token pool inside the old mining
contract forced a full-set redeploy. Deployer EOA #4 (0x760B7c6eEa1b61470E52E737C49Fb30b9f63ec79,
funded 0.00055 BNB from mee.ai, tx 0x3cfb78a3cd9a6b29bfc8d218b62949ec085d3a21a9b6c800deb9b4a77bd0c0de;
leftover 0.000176 BNB swept back, tx 0x561fccafaacd198de2079f43855e88c9fdce2e06ca6abbeb542b9d002c05a23d;
deployer balance 0 afterwards, key shredded), nonces 0/1/2:

- **G1999Token v4: 0xDb8911F5072ab679e2084A34b5D3cF39EbC96DD4** (tx 0xb6ae04500d267ac77de5968387f300dc9f0efb7f3a53e249f70754547075fdb9, gasUsed 734,311)
  - mining vault = predicted Mining1999 v4 address; 34,496,550 pool allocated at creation (verified).
- **Genesis1999 v4 (NFT): 0xCfB8fb0FaC63C43d83959129F9C92CFBf5f42977** (tx 0x5bd6fe65c4da979b806f625806d01cfa17d5056470350a89240e34d8d3daaa16, gasUsed 5,202,716)
  - On-chain verified at deploy: tierOf samples match metadata tiers; freeRemaining
    1100/352/150/39; saleRemaining 68/75/100; teamRemaining 30/25/15; miningRemaining 45;
    totalMinted 0; freeMintActive = false, saleActive = false.
- **Mining1999 v4: 0xbD8ED0C9f69e3E0b509Da436812EF70B582291c7** (tx 0xee57a293127fdc456c108e70f219b81cc146c951e66fd12e86f9b165c600e4f7, gasUsed 1,430,174)
  - Defaults verified in source: ladder [3,5,7,12], baseWeight 1, usdPerPower 40,000,000.
- All three owned by mee.ai (transfers 0xcfa44722…, 0x3ee2b3c4…, 0x36a7ecd6…).
  mee.ai holds 65,493,450 G1999 v4; total supply 99,990,000.
- v3 set (token 0xC3c403ed…, NFT 0x19ec51c1…, mining 0xcc26bACC…) is SUPERSEDED/inert.
  Canonical set is now the v4 set above.

## Launch notes (v4, 2026-10-31)

- IPFS pinning via Filebase CAR import (1 pin per folder DAG):
  images bafybeigdds6grrv6uxnskxvwjv7apcdya4r7tbp27cudukq7dahekqqnvu,
  metadata bafybeifvkhpxkfgbizxyo5ftntqx5jkmogr4z5olgswnyryhcfgiaigymm.
  setBaseURI tx 0x94abef3de400522bdd0e6ee025ab2c1d09aca0b22e9427cdd6ed8934e6452c23.
  Mining tokenPriceUsd set to 90917 ($0.00090917).
- KNOWN NOTE: mintMiningReserve uses _safeMint, and Mining1999 does not
  implement IERC721Receiver, so minting the mining reserve TO the mining
  contract reverts. The 45 Legendary mining-reserve NFTs are therefore held
  in the owner wallet (mee.ai) as the project reserve, which matches
  PLAN.md's intent (special mining rewards distributed by the owner).
  Team reserve: 70 NFTs (Rare 30, Epic 25, Legendary 15) in the owner wallet.
- LAUNCHED LIVE 2026-10-31 ~20:45 Asia/Dhaka: reserve mints complete
  (totalMinted 115, all in the owner wallet), then
  setFreeMintActive(true) tx 0x0fac53377822f5a03a1ecb01e63674e34ed0b2cb8bd5dc6eab56ba43a3d98047,
  setSaleActive(true) tx 0xae5048dbb356ca4f6b4f7e04cc2cae38bb3af871a07cbee26c3178e82bf05289,
  startMining() tx 0x0173fe5950d8ad5b1b11d968544de38fc20604c456d6078a80dc19ddd1211e19.
  Verified: freeMintActive=1, saleActive=1, started=1 (startTime 1793457926),
  all receipts status 1; free pool 1,641 and sale 243 untouched.
