# BLIND_LIST — C4 `2025-10-hybra-finance`（盲测清单 · 读官方 report **之前**落盘）

- **跑测人:** 桑多涅（子线程 C4 self-benchmark #2, blind run）
- **落盘时间:** **2026-09-27T23:52:47+08**（`date` 读数；写入本文件的 exec 时点）
- **靶:** C4 contest `2025-10-hybra-finance`（$33,000 · 2025-10-06 → 10-16 · Hyperliquid 流动性层）
  - 代码: VPS `192.227.190.145:/tmp/bench/2025-10-hybra-finance`（`git clone --depth 1`，上游 main）
  - 本机工作副本: `/root/defi-practice/bench/hybra-2025-10/`
- **分母（任务书预验，未复算）:** 官方 **H+M = 10（1H + 9M）**
- **⚠️ 盲测纪律声明:** 本文件落盘时，**未读**官方 report、**未读**仓库自带 `Hybra-V12-output.md`（Zellic V12 AI 输出，README 明文 OOS）、**未读** `discord-export/`、`audit/`。只读了 `scope.txt` / `out_of_scope.txt` / `README.md`（程序事实）+ in-scope 的 14 个 `.sol` + 其 import 的库/接口（HybraTimeLibrary / IRHYBR / IGHYBR / ISwapper 等，均为 OOS 上下文）。

---

## 1. 范围（in-scope 清单 + SLOC）

**口径:** `hunt-kit/scripts/sloc.sh`（唯一口径）；in-scope = `scope.txt` 的 **14** 个文件。

| 文件 | SLOC |
|---|---|
| ve33/contracts/VotingEscrow.sol | 801 |
| ve33/contracts/GaugeManager.sol | 411 |
| ve33/contracts/GovernanceHYBR.sol | 367 |
| ve33/contracts/GaugeV2.sol | 273 |
| ve33/contracts/CLGauge/GaugeCL.sol | 258 |
| cl/contracts/core/CLFactory.sol | 205 |
| ve33/contracts/VoterV3.sol | 195 |
| ve33/contracts/RewardHYBR.sol | 187 |
| ve33/contracts/MinterUpgradeable.sol | 169 |
| cl/contracts/core/fees/DynamicSwapFeeModule.sol | 149 |
| ve33/contracts/HYBR.sol | 81 |
| ve33/contracts/swapper/HybrSwapper.sol | 82 |
| ve33/contracts/CLGauge/GaugeFactoryCL.sol | 72 |
| cl/contracts/core/CLPool.sol | 795 |
| **TOTAL (sloc.sh)** | **4045** |

- **回读核对:** `sloc.sh --list` 输出 **14 行**（= `scope.txt` 14 条 ✓）；`--total` = 4045。
- **口径声明:** 官方 README **未给 nSLOC 数字**（只列 14 文件表）⇒ 本次与官方 **不可比/无可比对象**，不混用。
- **机械三连:** `fork_lineage` 谱系指纹（ve33）= synthetix-staking 15 · openzeppelin 9 · uniswap-v2 6 · uniswap-v3 2 · curve-stableswap 2 · masterchef 1；（cl/core）= uniswap-v3 5。`primitive_scan` 全库命中 7018 行。
  - **结论:** 本靶是 **Solidly/Blackhole(ve33) + Uniswap-V3(cl)** 的混合分叉。差分对象（上游 Blackhole）不在本仓（shallow clone 仅 1 commit），**差分优先读无从下手** ⇒ 全量通读 14 文件。

---

## 2. 我们的候选清单（"我们会提交什么"）

> 严重度 = 我们**盲测时**给的档（未看官方）。可达性 = 能不能被**非特权**地址触发。

| # | file:line | 机制（一句话） | 我们给的严重度 | 可达性依据 |
|---|---|---|---|---|
| **B-01** | `ve33/contracts/GovernanceHYBR.sol:137` + `:144`（`deposit_for` 先于 `calculateShares`） | `deposit()` **先**把 HYBR 锁进 veNFT，**再** `calculateShares(amount)` 用**已含本次存款**的 `totalAssets()` 算份额 ⇒ 新存款人拿到的 gHYBR 份额按 `TA_after` 计算，**每笔后续存款都被稀释**，价值转移给先存者 | **H** | 任意地址 `deposit()`（无权限）；`deposit_for` 立即抬高 `locked[veTokenId].amount` |
| **B-02** | `GovernanceHYBR.sol:191` + `VotingEscrow.sol:1169` | `withdraw()` 分解为 `[remaining, user, fee]` 三段喂给 `multiSplit`；`require(remainingAmount >= 0)` 是 **uint 恒真**的废检查。赎回全部份额 ⇒ `remaining==0`；小额 ⇒ `feeAmount==0` ⇒ `multiSplit` 的 `require(amounts[i]>0,"ZW")` 直接 revert ⇒ **无法全额退出**（可用性/DoS） | **M** | 任意 gHYBR 持有人；`withdrawFee>=10bps`、`BASIS=10000` |
| **B-03** | `VotingEscrow.sol:1153-1200`（`multiSplit`）+ `:584`（`permanentLockBalance`） | 子 NFT 金额逐项 **向下取整**（`original*amounts[i]/totalWeight`），Σ子 < 父；且 burn 原 NFT 时**不调整** `permanentLockBalance` ⇒ 永久锁定总量与真实值漂移 + 尾差 dust 丢失 | **M/L** | 需 `canSplit[msg.sender]`；gHYBR 常态路径 |
| **B-04** | `VoterV3.sol:211`（`require(_poolWeight != 0,"ZV")`）+ `:158 poke` + `VotingEscrow.sol:833/888/960/1096` | ve 权重随时间衰减后，`poke()` 里 `_poolWeight = 旧票数*新权重/_totalVoteWeight` 可能取整为 **0** ⇒ `poke` revert；而 `deposit_for`/`increase_amount`/`merge`/`lockPermanent` 对 `voted[_tokenId]` 的 NFT **都调用 `poke`** ⇒ 该 NFT **无法再增加锁仓/合并**（核心功能 DoS） | **M** | 任意投票过的 veNFT 持有人，只受时间衰减影响 |
| **B-05** | `VoterV3.sol:141-143`（`_reset`）/ `:217-219`（`_vote`）+ `GaugeManager.setNewBribes` | `_reset`/`_vote` 取**当前** `gaugeManager.fetchInternal/ExternalBribeFromPool(pool)`；若 GAUGE_ADMIN 中途 `setNewBribes` 换 bribe，则**旧 bribe 里的 deposit 被弃**，withdraw/deposit 打到新 bribe ⇒ 票权与 bribe 账目**静默错位**（跨函数状态生命周期耦合） | **M** | 需 GAUGE_ADMIN 换 bribe + 用户重投/重置 |
| **B-06** | `GaugeManager.sol:330-338`（`distribute(address[])`）/ `:138-150`（`createGauges`）/ `:282-296`（`distributeFees`）/ `:477-490`（`claimRewards`） | 全部为「循环逐条处理、**单条 revert 即整批回滚**」的批处理；一条坏 gauge/nftId/池就把整批（含合法条目）打回 ⇒ 可用性面（**判据 1**） | **M/L** | 无权限入口：`distribute`/`distributeFees`/`createGauges`/`claimRewards` 均可被任意地址调用 |
| **B-07** | `GaugeManager.sol:470-475` | `claimRewards(address[] _gauges, uint8)` 把**每个** gauge 硬转 `IGauge(...).getReward(address,uint8)`；CL gauge（`GaugeCL`）没有该 selector（只有 `getReward(uint256,address,uint8)`）⇒ 列表里含 CL gauge 时整批 revert | **L** | 任意地址；混用 LP/CL gauge 时 |
| **B-08** | `GaugeManager.sol:373-397`（`_updateForAfterDistribution`） | `_supplied==0` 时（权重被 reset 为 0、或 gauge 刚 kill）直接 `supplyIndex[_gauge]=index`，**放弃已累积的 `_delta`**；且 `claimable` 只在该函数累积 ⇒ 这部分 emission **永久留在 GaugeManager** 无可提取路径 | **M** | 无权限；依赖投票在 epoch 内被 reset |
| **B-09** | `cl/contracts/core/fees/DynamicSwapFeeModule.sol:169-172` | swap 费折扣按 **`tx.origin`** 匹配 `discounted[]` ⇒ 可被中转合约/中继按 origin 蹭折扣（README 已把 Peckshield「Dynamic Fee Calculation」列为 public known） | **L** | swapFeeManager 注册折扣后；任意 swap |
| **B-10** | `ve33/contracts/RewardHYBR.sol:260-277`（`_beforeTokenTransfer`） | (a) `amount==0` 直接 revert ⇒ 破坏标准 ERC20 零额语义；(b) 在转账钩子里**写状态** `exempt.add(from)`（任何 `isGauge(from)` 即被永久加入白名单，是隐藏的状态副作用） | **L** | 任意 rHYBR 转账 |
| **B-11** | `GovernanceHYBR.sol:492-511`（`receivePenaltyReward`） | **无任何权限检查**的 external：任何人可把 gHYBR 账上**任意** HYBR 余额强制 lock 进其 veNFT（`penalty += amount` 记账同时被污染）⇒ 资金被强行锁死/记账欺骗（无直接窃取，因锁给自己） | **M/L** | 任意地址 |
| **B-12** | `RewardHYBR.sol:138-154` | `_redeemToHYBR` 先 `safeTransfer(gHYBR, penalty)`；若 `gHYBR` 未 set（=address(0)），ERC20 转账 revert ⇒ **TO_HYBR 赎回在 owner 设 gHYBR 前完全不可用**（配置依赖型可用性） | **L** | 任意 rHYBR 持有人，部署期窗口 |

**主动排除项（negative results，读码时明确检查过但判定不成立/不可达）:**

- **N-1** `GaugeManager` 的 `index`/`weights` 时序：`notifyRewardAmount` 在 `Minter.update_period()` 里读 `totalWeight`，而 `distributeAll` 同一 tx 内紧接着读各 gauge `weights` ⇒ 同一 tx 内 Σw==totalWeight，**不存在** epoch 间权重漂移导致的多/少分配（原本怀疑，检查后否定）。
- **N-2** `CLPool.calculateFees/splitFees/applyUnstakedFees`：`stakedFee + unstakedFee + protocolFee` 三段之和恒 = `feeAmount`（`mulDivRoundingUp` 的进位被 `feeAmount - stakedFee` 吸收），未发现泄漏。
- **N-3** `CLPool.collectFees/collectProtocolFees` 保留 1 wei 哨兵是**有意**（gas 优化），非漏洞。
- **N-4** `GaugeV2.withdraw` 的 `require(block.timestamp >= maturityTime[msg.sender])`：`maturityTime` **全合约从未赋值** ⇒ 恒为 0，检查形同虚设；判定为**死代码**而非可利用缺陷。
- **N-5** `DynamicSwapFeeModule.setScalingFactor` 要求 `feeCap != 0`；`getFee` 对 `totalFee` 做 `feeCap` 上限裁切 ⇒ 不能靠 dynamic 项把费率顶穿 `MAX_FEE_CAP`。
- **N-6** `HYBR.sol` 的 `unchecked` 加法只用于 `balanceOf[_to] += _amount`（减法在 checked 区）⇒ 无回绕获利路径。
- **N-7** `GaugeCL.deposit` 校验了「position 的池 == 本 gauge 池」并在 stake 前 `collect` 手续费、初始化 `rewardGrowthInside` ⇒ 未发现重复计奖；`receivePenaltyReward` 的 **public 无权限**（B-11）反倒是 gHYBR 侧的真问题。
- **N-8** `VotingEscrow._transferFrom`/`withdraw` 的 `attachments==0 && !voted` 守卫齐全，未发现「投票中转移/提取」绕过。

---

## 3. §3.5 两条新增判据 —— 逐条检查结论（**单列，必答**）

### 判据 1：批量操作的部分失败 —— **命中（成立）**
- **证据:** `GaugeManager.distribute(address[] _gauges)`（`:330-338`）循环调用 `_distribute`；`_distribute`→`IGauge/IGaugeCL.notifyRewardAmount` 任一 revert 即整批回滚。同型还有 `distributeFees()`（`:282`）、`distributeFees(start,finish)`（`:291`）、`createGauges()`（`:138`）、`claimRewards()`/`claimAllRewards()`（`:470/:483`）、以及 `CLFactory.collectAllProtocolFees()`。
- **结论:** **成立**，是**可用性/DoS 面**（`distribute` 把"某些 gauge 失败"的恢复手段反而变成全批失败）。我们把它记为 **B-06**（M/L）。
- **与我们上次的差别:** 上次（lido）我们把这种模式**判成了非问题**；本次**主动识别并落成候选**。

### 判据 2：跨函数状态生命周期耦合 —— **命中（成立）**
- **证据 A（强）:** `VoterV3._reset/_vote` 在**执行时**才向 `GaugeManager` 查询 bribe 地址（`:141-143`、`:217-219`）；`GaugeManager.setNewBribes`（`GAUGE_ADMIN`）可换 bribe ⇒ 投票时产生的 deposit 落在**旧 bribe**，重置/重投时打到**新 bribe** ⇒ 先前凭据（bribe 记账）静默失效。→ **B-05**。
- **证据 B（中）:** `GaugeManager._updateForAfterDistribution` 在 `_supplied==0` 时把 `supplyIndex` 抬到当前 `index`（`:373-397`），使 gauge 先前累积的 `_delta` **静默作废**，对应 emission 滞留合约。→ **B-08**。
- **证据 C（中）:** `GrowthHYBR.withdraw` → `VotingEscrow.multiSplit` 把合约的 `veTokenId` 替换为 `newTokenIds[0]`；原 tokenId 被 burn。任何**外部缓存了旧 tokenId**（如 operator 的投票记录、`lastVoteEpoch`）在 split 后即指向已销毁 NFT ⇒ 生命周期耦合。verdict：**结构性成立**，但未构造出直接资损路径。
- **结论:** **成立**（至少 A、B 两条实质命中）。

---

## 4. 不确定项（单列，不进结论）

| 项 | 为什么不确定 |
|---|---|
| B-01 是否被判 H 还是 M | 机制（份额稀释）确定，但"价值转移可否被协议自身的转账锁/白名单挡住"未做 PoC；`_addTransferLock` 只锁新增份额，**不阻止稀释**。 |
| B-03 permanentLockBalance 漂移 | 需要 `canSplit` + permanent NFT 组合；未算数值边界（dust 量级）。 |
| B-04 poke 失败面 | 需要权重衰减到"某池票数取整为 0"的具体参数（`_weight` 与 `_weights[i]` 比值），未在 fork 上复现。 |
| B-08 滞留资金规模 | 依赖「epoch 内权重被 reset 为 0」的真实发生频率，无链上数据。 |
| `HybraTimeLibrary.WEEK = 1800`（测试网配置） | in-scope 文件用的是库常量；若主网用注释里的 `7*86400`，B-02 的 TimeWindow 语义不同。库本身 OOS。 |
| 官方 10 条的**域**分布 | 未看官方（盲测纪律）；事后在 BENCHMARK 里分类。 |

---

## 5. 一句话（盲测时刻的自评）

> 最强候选是 **B-01（gHYBR 存款按"事后"totalAssets 算份额 ⇒ 后者补贴前者）**，属**记账/份额**族、非特权可达、无需领域知识。最不确定的是 CL gauge 的奖励增长数学（`GaugeCL/CLPool`），我们**没能在静态阅读下把它的奖励分配证伪或证实**——若官方 H 落在 CL 计奖，我们大概率漏。
