GENESIS1999 (G1999) AIRDROP CLAIM — PROMPT FOR YOUR AI AGENT

Copy everything below the line and give it to your AI agent. The agent will claim your $G1999 airdrop for you.

--------------------------------------------------

You are helping me claim my Genesis1999 (G1999) holder airdrop on BNB Smart Chain (chainId 56). Follow these steps exactly and verify every step on chain before and after.

FACTS
- Airdrop distributor contract (G1999Airdrop): 0xa483E8378CE6bCE5a9816Ad461e0B489758931bF
- Source code is verified on Sourcify with an exact match. Contract file G1999Airdrop.sol is also in the official GitHub repo github.com/MrMxBlack/genesis1999 under the airdrop folder.
- G1999 token: 0xDb8911F5072ab679e2084A34b5D3cF39EbC96DD4
- The airdrop covers all 1,756 minted Genesis1999 NFTs (842 holder wallets). Total pool: 24,497,550 G1999, already funded in the distributor.
- Claim deadline: 2027-11-04 17:10 UTC. After that, unclaimed tokens can be withdrawn by the owner.

STEPS
1. Get my claim data. Download claims.json from the official GitHub repo (github.com/MrMxBlack/genesis1999, airdrop folder) and find the entry for MY wallet address. It contains amountWei, feeUsdCents, and proof (an array of bytes32 hashes). If my wallet is not in the file, I have no claim — stop and tell me.
2. Check the contract state: claimsActive() must be true, and claimed(myAddress) must be false. If I already claimed, stop and tell me.
3. This is a PAID claim. The fee is charged in BNB at the live Chainlink BNB/USD rate and is priced per NFT I hold: Common $0.03, Rare $0.07, Epic $0.11, Legendary $0.15. My total fee in USD cents is the feeUsdCents value from my claims.json entry. Call feeInBnb(feeUsdCents) on the distributor to get the exact BNB amount.
4. Before executing, show me a preview of the transaction and get my confirmation. The ONLY things that may happen: I pay the fee in BNB (it is forwarded to the project treasury in the same transaction) and I receive amountWei of G1999. There must be NO token approval and NO other balance change. Any overpayment above the fee is refunded by the contract automatically.
5. Claim: call claim(amountWei, feeUsdCents, proof) on the distributor and send at least feeInBnb(feeUsdCents) as the transaction value. Use the amountWei, feeUsdCents and proof values from my claims.json entry exactly as they are.
6. Verify after the transaction: my G1999 balanceOf increased by amountWei, and claimed(myAddress) is now true. Report the transaction hash and my new G1999 balance.

SAFETY RULES
- Use ONLY the distributor address above. Never send BNB or approve anything to any other contract or address for this claim.
- The claim needs NO token approval. If any website or message asks for an approval, a different contract, or my seed phrase or private key, stop immediately — that is a scam.
- Never change the amount, fee or proof values. If the claim reverts, report the error to me instead of trying other values.

--------------------------------------------------

Notes for holders (not part of the agent prompt):
- You claim from the same wallet that holds your Genesis1999 NFTs.
- One claim per wallet. The fee is paid once per wallet, not per NFT.
- Questions: X @Genesis1999G, Telegram t.me/Genesis1999G
