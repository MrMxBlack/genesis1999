# Genesis1999, Source Verification Record

Verified via Sourcify v2 API (https://sourcify.dev/server/v2), chain 56 (BNB Smart Chain).
Compiler: solc v0.8.26+commit.8a97fa7a · evmVersion shanghai · optimizer 200 runs ·
OpenZeppelin Contracts 5.1.0. Recompiled standard-JSON input reproduces the deployed
bytecode byte-for-byte for all three contracts (checked locally before submitting).

## Genesis1999 (NFT), EXACT MATCH

- Address: 0x19ec51c1492aeb41e211891206a9b58bd7a965a1
- Submitted: 2026-10-31 · verificationId b6270c84-fddf-4025-accc-6490072e3bdc
- Result: match = exact_match · creationMatch = exact_match · runtimeMatch = exact_match
- Sourcify matchId: 57776482 · verifiedAt 2026-10-31T05:51:57Z
- Contract page: https://sourcify.dev/#/lookup/0x19ec51c1492aeb41e211891206a9b58bd7a965a1
- Note: Sourcify's optional forwarding to Etherscan failed on their side with
  "Daily limit of 500 source code submissions reached", unrelated to this
  verification (and BscScan is a separate explorer).

## G1999Token v3, EXACT MATCH

- Address: 0xC3c403ed9297f059B633cEdAA75Bf0602419D8e6
- Submitted: 2026-10-31 · verificationId 0a017448-bf46-45a8-8ead-2f382c7db5ba
- Result: match = exact_match · creationMatch = exact_match · runtimeMatch = exact_match
- Sourcify matchId: 57778436 · verifiedAt 2026-10-31T06:14:27Z
- Contract page: https://sourcify.dev/#/lookup/0xC3c403ed9297f059B633cEdAA75Bf0602419D8e6
- Note: the first submission failed silently because the compiler version string
  carried a ".Emscripten.clang" suffix; stripping it fixed the submission.

## Mining1999 v3, EXACT MATCH

- Address: 0xcc26bACC9429D3a861623a05793B0812D965A71b
- Submitted: 2026-10-31 · verificationId 45e6a88e-65ee-41db-9519-4df7eb2971a8
- Result: match = exact_match · creationMatch = exact_match · runtimeMatch = exact_match
- Sourcify matchId: 57778582 · verifiedAt 2026-10-31T06:15:58Z
- Contract page: https://sourcify.dev/#/lookup/0xcc26bACC9429D3a861623a05793B0812D965A71b

## v4 set (tier-queue fix), ALL EXACT MATCH

- G1999Token v4: 0xDb8911F5072ab679e2084A34b5D3cF39EbC96DD4
  match = exact_match · creationMatch = exact_match · runtimeMatch = exact_match
  Sourcify matchId: 57832671 · verifiedAt 2026-10-31T14:18:32Z
- Genesis1999 v4 (NFT): 0xCfB8fb0FaC63C43d83959129F9C92CFBf5f42977
  match = exact_match · creationMatch = exact_match · runtimeMatch = exact_match
  Sourcify matchId: 57832757 · verifiedAt 2026-10-31T14:19:43Z
- Mining1999 v4: 0xbD8ED0C9f69e3E0b509Da436812EF70B582291c7
  match = exact_match · creationMatch = exact_match · runtimeMatch = exact_match
  Sourcify matchId: 57832876 · verifiedAt 2026-10-31T14:20:53Z
