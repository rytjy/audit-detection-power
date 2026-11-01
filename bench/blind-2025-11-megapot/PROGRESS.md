
## Blind bench #4 — megapot 2025-11 — START 2026-10-01 15:30
- scope: 16 in-scope .sol (4401 lines total, Jackpot.sol alone 1728)
- Plan: write skeleton CANDIDATES.md first, then read files in order: lib -> interfaces -> NFT -> entropy -> calculators -> LPManager -> BridgeManager -> Jackpot.sol -> re-read cross links
15:30
- 15:31 read libs (Combinations/FisherYates/Errors/UintCasts/TicketComboTracker) + all 5 interfaces + JackpotTicketNFT (206L). Notes: combo tracker inclusion-exclusion; NFT transfer list mgmt.
- 15:40 read Jackpot.sol 1-1728 (full). Noted: claimWinnings/_payReferrersWinnings lpEarnings redirect, _setNewDrawingState bonusball calc, _calculateTicketTierId, emergencyRefund.
- NEXT: ScaledEntropyProvider, GuaranteedMinimumPayoutCalculator, JackpotLPManager, JackpotBridgeManager
- READ ALL 16/16 in-scope files (4401 SLOC): libs(5) + interfaces(5) + Jackpot.sol(1728) + LPManager(539) + BridgeManager(370) + PayoutCalc(456) + EntropyProvider(340) + TicketNFT(206).
- Read sponsor docs: documentation/auditor-intro.md (12 guiding questions + flow diagrams), DOCUMENTATION.md, README.md (publicly-known list: rounding dust / emergency refunds / referral fallback).
- Cross-reads done: (1) accounting identity LP pool<->prizePool<->referral ledger; (2) lifecycle accumulator<->deposit/withdraw<->settlement; (3) batch x external call (claimWinnings, emergencyRefundTickets, bridge); (4) bit-collision analogue normals vs bonusball bit; (5) cross-contract ABI/getter check incl. uint64->bytes32 callback decode; (6) overwrite-update vs prior entitlements.
- Negatives verified by re-reading: tier math (inclusion-exclusion indices), payout solvency bound, entropy callback cannot be attacker-routed (callback = msg.sender), double-settle guarded by jackpotLock, NFT list swap-and-pop.
- Found 7 candidates (0 H / 3 M / 4 L-ish). Strongest: C-01 refunded tickets remain in combo tracker + callback not gated by noEmergencyMode; C-03 bridge ticketPrice global-vs-snapshot desync w/ no sweep; C-02 uint8 truncation of newBonusball.
- CAVEAT: lib/solady NOT vendored in checkout -> solady ERC721 self-transfer/ownerOf semantics unverifiable locally; flagged in negated #9.
- DONE. CANDIDATES.md written (14,335 bytes).
