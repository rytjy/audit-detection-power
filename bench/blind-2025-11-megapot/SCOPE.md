# SCOPE — C4 2025-11-megapot（in-scope 16 文件）

口径：`hunt-kit/scripts/sloc.sh`（唯一口径）。in-scope 总数 **2,562 SLOC**（含 5 个 interfaces）。

| 文件 | SLOC |
|---|---|
| contracts/Jackpot.sol | 787 |
| contracts/JackpotLPManager.sol | 198 |
| contracts/lib/TicketComboTracker.sol | 188 |
| contracts/GuaranteedMinimumPayoutCalculator.sol | 173 |
| contracts/ScaledEntropyProvider.sol | 156 |
| contracts/JackpotBridgeManager.sol | 153 |
| contracts/JackpotTicketNFT.sol | 103 |
| contracts/lib/JackpotErrors.sol | 61 |
| contracts/lib/Combinations.sol | 52 |
| contracts/lib/FisherYatesWithRejection.sol | 36 |
| contracts/interfaces/IJackpot.sol | 23 |
| contracts/interfaces/IJackpotLPManager.sol | 23 |
| contracts/interfaces/IJackpotTicketNFT.sol | 24 |
| contracts/interfaces/IPayoutCalculator.sol | 17 |
| contracts/interfaces/IScaledEntropyProvider.sol | 19 |
| contracts/lib/UintCasts.sol | 22 |
| **TOTAL (in-scope)** | **2,562** |

out-of-scope：`contracts/mocks/*`（11 个）+ 一切未列于 `scope.txt` 者。
