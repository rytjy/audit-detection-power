# Blind bench #4 — megapot 2025-11 — CANDIDATES

> Method: blind read of `_repo/contracts/**` (16/16 in-scope files, 4401 SLOC) + sponsor docs
> (`documentation/auditor-intro.md`, `DOCUMENTATION.md`, `README.md`). No findings/audit text, no network.
> Judgement gates applied: BOX_TEMPLATE §3.5 (1–7) and §3.6 reverse gate (who loses / is the premise reachable /
> design choice? / does the attacker profit / already covered).
> Deliberate cross-reads performed: ① accounting identity (LP pool / prize pool / referral ledger),
> ② cross-function state lifecycle (accumulator ↔ deposit/withdraw ↔ settlement), ③ batch × untrusted external call,
> ④ "same-name collision" analogue = packed-ticket bit collision (normals 1..normalMax vs bonusball bit normalMax+bb),
> ⑤ cross-contract getter/ABI check (IJackpot / IJackpotLPManager / IPayoutCalculator / IScaledEntropyProvider,
> and the `uint64 sequence` ↔ `bytes32` callback decode), ⑥ overwrite-type state update vs prior entitlements.

## Candidate table

| # | file:line | mechanism (one line) | sev | reachability (who triggers, what perms) | conf |
|---|---|---|---|---|---|
| C-01 | `contracts/Jackpot.sol:581-601` (+ `:717-749`, `:1614-1649`, `:1590`) | `emergencyRefundTickets` burns the NFT but never removes the ticket from `drawingEntries` combo tracker; the still-pending entropy callback is **not** gated by `noEmergencyMode`, so it can settle the same drawing and count refunded tickets as winners ⇒ userWinnings (the LP-pool debit at `processDrawingSettlement`) includes ghost tickets nobody can ever claim ⇒ LP pool permanently debited / USDC stranded. | M | Owner calls `enableEmergencyMode()` while `jackpotLock==true` (callback in flight), any refunded user calls `emergencyRefundTickets`, then Pyth delivers the pending callback. No attacker perms needed beyond being a ticket holder. | med |
| C-02 | `contracts/Jackpot.sol:1494-1497` (cast at `:1496`) | Raw `uint8(...)` cast of the computed `bonusballMax` (silent truncation) — the repo has `UintCasts.toUint8` and uses it at `:1628`, but not here. If the truncated value exceeds `255 - normalBallMax`, the bonusball bit `1 << (bb + normalMax)` is a shift ≥ 256 ⇒ EVM returns 0 ⇒ the bonusball is silently dropped from `packedTicket` ⇒ tier grading is wrong (a 5+b ticket is graded tier 10 instead of 11) and `unpackTicket` underflows (`TicketComboTracker.sol:342`). | M | Config+sales-volume dependent: post-settlement LP value must imply >255 bonusball values, i.e. `newPrizePool ≥ 256·C(normalBallMax,5)·(1-lpEdge)·ticketPrice`. Feasible only with small `normalBallMax` + high sales; `lpEarnings` (and hence `newPrizePool`) is not capped by `lpPoolCap`. | low-med |
| C-03 | `contracts/JackpotBridgeManager.sol:178-184` (vs `Jackpot.sol:382`, `:1127-1134`, `:1486`) | Bridge quotes/charges/approves `jackpot.ticketPrice()` (the **global**, mutable by `setTicketPrice`) but Jackpot charges `drawingState[currentDrawingId].ticketPrice` (a **per-drawing snapshot**). After a mid-drawing `setTicketPrice`: (a) if raised, the user overpays and the delta is stuck in BridgeManager — there is **no sweep/withdraw function**; (b) if lowered, the approve is short and `jackpot.buyTickets` reverts ⇒ bridge route DoS. | M | Owner calls `setTicketPrice` while a drawing is live; any user using the bridge route buys. | med |
| C-04 | `contracts/Jackpot.sol:591-592` | `emergencyRefundTickets` prices the referral deduction with the **current** global `referralFee`, not the rate applied at purchase ⇒ if `referralFee` is changed between purchase and the emergency refund, refunds are over- or under-paid (protocol/LP loss or user loss). Ticket state records only *whether* a scheme applied, never the rate. | L | Owner calls `setReferralFee` mid-drawing, then enables emergency mode. | med |
| C-05 | `contracts/Jackpot.sol:886-893`, `:296-325` (no validation) → `Jackpot.sol:1494`/`GuaranteedMinimumPayoutCalculator.sol:451`/`FisherYatesWithRejection.sol:53` | `normalBallMax` is validated only as `uint8`. For `normalBallMax ≤ 9`, `Combinations.choose(_normalMax - 5, 5 - matches)` hits `assert(n >= k)` (`Combinations.sol:15`) ⇒ settlement reverts forever; for `normalBallMax > 128`, `assert(n <= 128)` (`:16`) reverts; for `normalBallMax < 5`, the entropy draw `require(count <= maxRange-minRange+1)` reverts. The drawing can never settle ⇒ jackpot stuck (only emergency mode rescues). | L | Owner-only misconfiguration (constructor accepts any uint8, `setNormalBallMax` has no lower bound). | high (mechanism) / low (severity) |
| C-06 | `contracts/JackpotBridgeManager.sol:225-243` (vs `:341`, `:368`) | `claimWinnings` never clears `ticketOwner[ticketId]` although the NFT is burned underneath ⇒ the entry is stale forever; a later `claimTickets` for the same id passes `_validateTicketOwnership` and then reverts in `safeTransferFrom` (burned token) ⇒ that path is DoS'd, and off-chain keepers that trust `ticketOwner` are misled. No funds extracted. | L | Any bridge-route ticket owner who claims winnings then tries the same ids. | high (mechanism) |
| C-07 | `contracts/JackpotBridgeManager.sol:268` | `claimTickets` lacks `nonReentrant` (its sibling `claimWinnings:225` has it) while it makes an external `safeTransferFrom` (→ `onERC721Received`). State (`ticketOwner`) is deleted before the call, so I could **not** build an exploitation path; reporting as a hardening/consistency defect only. | L | n/a (no impact proven) | low |

### keywords per candidate (for score.py lexical matching)

- C-01 `keywords: emergencyRefundTickets burnTicket combo tracker stale state refunded ticket still counted winner settlement lpEarnings LP pool debited ghost winners stranded funds emergency mode callback not gated`
- C-02 `keywords: newBonusball uint8 truncation unsafe downcast silent wrap bonusballMax bit packing shift 256 bonusball bit dropped packedTicket tier grading wrong unpackTicket underflow`
- C-03 `keywords: JackpotBridgeManager ticketPrice desync global vs drawing snapshot setTicketPrice overpay stranded funds no sweep approve shortfall buyTickets revert bridge route DoS`
- C-04 `keywords: emergencyRefundTickets referralFee current value mid-drawing refund mismatch purchase-time rate over-refund under-refund`
- C-05 `keywords: normalBallMax validation missing lower bound choose assert revert settlement cannot settle jackpot stuck drawing never progresses`
- C-06 `keywords: ticketOwner stale not deleted after claimWinnings burned NFT replay claimTickets revert keeper misled`
- C-07 `keywords: claimTickets missing nonReentrant reentrancy guard inconsistent external call onERC721Received`

### Minimum PoC shape (per candidate)

- **C-01**: hardhat/foundry test. In one drawing: buy N tickets (hold a known combo), `runJackpot()` (lock, entropy mock queues callback), `enableEmergencyMode()`, `emergencyRefundTickets([myIds])` → assert USDC refunded; then fire the entropy mock callback → assert `JackpotSettled.userWinnings > 0` while `jackpotNFT.ownerOf(id)` reverts and no claim is possible; assert `getDrawingAccumulator`/next `prizePool` reflect a debit that no one can withdraw (compare `usdc.balanceOf(jackpot)` against the sum of all live entitlements).
- **C-02**: unit-test the pure path: call `_setNewDrawingState`-equivalent inputs so `minNumberTickets/combosPerBonusball ≥ 256` (small `normalBallMax`, big `newLpValue`), then assert `drawingState[id].bonusballMax` is the truncated value; assert `1 << (bonusballMax + normalMax) == 0`; then buy a 5+b ticket and assert `getTicketTierIds` returns 10 (not 11) / `getUnpackedTicket` reverts.
- **C-03**: buy N tickets via bridge (price P), `setTicketPrice(P')` mid-drawing, buy again → assert `usdc.balanceOf(bridgeManager)` retains `(P'-P)*n` and that there is no function able to move it; repeat with `P' < P` to assert revert.
- **C-04**: buy a ticket with a referral scheme at `referralFee=f1`, `setReferralFee(f2)`, `enableEmergencyMode`, refund → assert refund ≠ `ticketPrice*(1-f1)`.
- **C-05**: `setNormalBallMax(9)` (or deploy with 9), buy a ticket, `runJackpot` + entropy callback → assert revert in `calculateAndStoreDrawingUserWinnings` and that the drawing can never progress.
- **C-06**: bridge-buy, `claimWinnings(...)`, then `claimTickets(sameIds, me, sameSig)` → assert revert; assert `ticketOwner[id]` still set.

## Negated list (read, judged not-a-bug, with reason)

1. `Jackpot._calculateTicketTierId:1651-1669` — `matches - bonusballMatch`: bonusball bit is at `normalMax+bb` (bb≥1) and normal bits are `1..normalMax`, so `&` can never collide; `bonusballMatch ≥ 1` whenever the bb bit matches, so **no underflow**. Correct. (§3.5-④ analogue checked, negative.)
2. `TicketComboTracker._countSubsetMatches:145-171` + `_applyInclusionExclusionPrinciple:173-207` — indices 0/1 are never written by the `k≥1` loop, `result[0]` stays 0 (tier 0 legitimately pays nothing), `[2k+1]` is the bb-match series consistent with `tier = 2k+bb`. Arrays sized `(normalTiers+1)*2` — max index 11. Mathematically exact; no double-count found.
3. `GuaranteedMinimumPayoutCalculator.calculateAndStoreDrawingUserWinnings:167-217` — total payout is bounded by `prizePool`: `Σ tierPayout_i·tierWinners_i = remaining ≤ prizePool` and `unique_i+dup_i ≤ tierWinners_i` (denominator uses *all possible* combos per `_calculateTierTotalWinningCombos`). Pool never over-committed (answers guiding Q10 negatively).
4. `JackpotLPManager.processDrawingSettlement:371-392` ↔ `_consolidateDeposits:522-529` ↔ `initializeDrawingLP:408` — deposit-at-NAV is self-consistent (`newPrice == acc[D]` after adding `pendingDeposits`); sum of per-LP `floor(shares·acc/1e18)` ≤ `lpPoolTotal`; withdrawal shares are debited from the pool exactly once at settlement. No accumulator/dilution exploit found.
5. `ScaledEntropyProvider.requestAndCallbackScaledRandomness:133-150` — callback address is forced to `msg.sender`, so an attacker **cannot** make the provider call `Jackpot.scaledEntropyCallback` with attacker-chosen ranges; `pending[sequence]` is deleted before the call. Attack path closed.
6. `Jackpot.scaledEntropyCallback` double-settle — guarded by `jackpotLock` on the current drawing + `currentDrawingId` bump; sequence replay impossible (`UnknownSequence`). Negative.
7. `Jackpot.runJackpot:646-691` — excess-ETH refund to `msg.sender` before the entropy call, but `nonReentrant` covers the entry points; refund failure reverts the whole call by design. Negative.
8. `Jackpot.buyTickets:365-393` duplicate top-up `ticketPrice - edgePerTicket` — consistent with the documented "preserve LP edge"; the per-ticket accounting identity (revenue = lpEarnings + referralFeeTotal) holds. Negative.
9. `JackpotTicketNFT._beforeTokenTransfer/_afterTokenTransfer:170-196` — swap-and-pop list maintenance is index-correct for mint/transfer/burn; `tickets[id].drawingId` is immutable per ticket and `ticketId = keccak256(drawingId, seq, packedTicket)` is collision-free, so `from` always holds the entry. **Not verified**: solady `ERC721` is not vendored in this repo, so the `from == to` self-transfer behaviour could not be checked locally (§3.6 caveat).
10. `Jackpot.claimWinnings:418-452` — duplicate ids in one array / re-claim all revert via `ownerOf` on a burned solady token (unverified dependency) and via burn; referral-share fallback to `drawingState[currentDrawingId].lpEarnings` matches the documented public "Referral Fallback" policy. Negative.
11. `Jackpot._transferProtocolFee:1700-1713` — protocol fee is both transferred and deducted from `postDrawLpValue`; no double-charge. Negative.
12. Cross-contract ABI check ⑤ — `IJackpot/IJackpotLPManager/IJackpotTicketNFT/IPayoutCalculator/IScaledEntropyProvider` signatures all match the implementations (incl. `SetRequest` struct layout), and the provider's `abi.encodeWithSelector(selector, uint64, uint256[][], bytes)` decodes correctly into `bytes32` (single word). Negative.
13. `GuaranteedMinimumPayoutCalculator` tier-0 `minPayoutAllocation` (line 199-203) — if an owner marks tier 0 min-eligible, `tierWinners[0] = C(n-5,5)·(bbMax-1)` is huge and `useMinimumPayouts` becomes false, silently disabling minimums. Judged a documentation/config smell (§3.6-3: "just config"), not reported.

## Coverage — in-scope 16 (all read line-by-line)

TOTAL: 4401 SLOC (16 files). COVERED: 16/16 (100%).

| file | SLOC | status |
|---|---|---|
| `contracts/lib/Combinations.sol` | 69 | READ |
| `contracts/lib/FisherYatesWithRejection.sol` | 89 | READ |
| `contracts/lib/JackpotErrors.sol` | 72 | READ |
| `contracts/lib/TicketComboTracker.sol` | 343 | READ |
| `contracts/lib/UintCasts.sol` | 48 | READ |
| `contracts/GuaranteedMinimumPayoutCalculator.sol` | 456 | READ |
| `contracts/Jackpot.sol` | 1728 | READ (full, incl. all view/admin setters) |
| `contracts/JackpotBridgeManager.sol` | 370 | READ |
| `contracts/JackpotLPManager.sol` | 539 | READ |
| `contracts/JackpotTicketNFT.sol` | 206 | READ |
| `contracts/ScaledEntropyProvider.sol` | 340 | READ |
| `contracts/interfaces/IJackpot.sol` | 29 | READ |
| `contracts/interfaces/IJackpotLPManager.sol` | 35 | READ |
| `contracts/interfaces/IJackpotTicketNFT.sol` | 30 | READ |
| `contracts/interfaces/IPayoutCalculator.sol` | 26 | READ |
| `contracts/interfaces/IScaledEntropyProvider.sol` | 21 | READ |

UNREAD: none in scope. Out of scope by rule: `contracts/mocks/**` (11 files), `test/**`, `scripts/**` — not read;
**cost: solady dependency behaviour (ERC721 `_transfer` on `from == to`, exact `ownerOf`/`_burn` semantics) could not
be verified because `lib/solady` is not present in the checkout** (see negated #9 and limits).

## Delivery / strongest 3

1. **C-01 `Jackpot.sol:581-601`** — refunded tickets stay in the combo tracker while the drawing can still settle ⇒ LP pool charged for unclaimable winners.
2. **C-03 `JackpotBridgeManager.sol:178-184`** — global-vs-snapshot `ticketPrice` desync strands user USDC in a contract with no sweep (or DoSes the bridge route).
3. **C-02 `Jackpot.sol:1496`** — silent `uint8` truncation of `newBonusball`, with the bit-packing collapse (`1 << (bb+normalMax) == 0`) as the impact when the truncated value exceeds `255 - normalBallMax`.
