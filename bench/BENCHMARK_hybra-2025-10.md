# BENCHMARK — C4 `2025-10-hybra-finance`（自我基准 #2 · 我们的第一次"真分母"测量）

- **跑测人:** 桑多涅（子线程 C4 self-benchmark #2, blind run）
- **日期:** 2026-09-27（T0 23:48 +08 → 交付 ~00:15 +08，用时 ~30min，时间盒 120min 内）
- **靶:** C4 contest `2025-10-hybra-finance`（$33,000 · 2025-10-06 → 10-16 · Hyperliquid 流动性层）
  - 代码: VPS `192.227.190.145:/tmp/bench/2025-10-hybra-finance`（`git clone --depth 1`，上游 `main`）
  - 本机工作副本: `/root/defi-practice/bench/hybra-2025-10/`
- **官方结论（原文）:** *"The C4 analysis yielded an aggregated total of **10 unique vulnerabilities**. Of these vulnerabilities, **1** received a risk rating in the category of **HIGH** severity and **9** received a risk rating in the category of **MEDIUM** severity."* 另 *45 reports* 为 Low/Non-critical。
- **官方来源:** https://code4rena.com/reports/2025-10-hybra-finance （HTTP 200；`curl` 落盘 `/tmp/hybra_report.html`，**mtime 2026-09-27 23:54:29 +08**；`web_fetch` 快照 15:54:55Z）
- **官方口径的代码来源:** `hybra-finance/hybra-finance` @ commit `480cb4ee6e604bdc9169f89094499bbc774f3dfa`（报告 Scope 段）

---

## 🔒 0. 盲测纪律 —— 遵守情况（自述 + 证据）

| 检查 | 结果 |
|---|---|
| 第一步：拉码 → `box_triage` → 读 in-scope → 形成并**落盘**"我们会提交什么" | ✅ 盲测清单 `/root/defi-practice/hunt-kit/bench/BLIND_LIST_hybra-2025-10.md`（104 行） |
| 清单落盘时间（`stat`） | **2026-09-27 23:53:12 +08** |
| 官方材料首次抓取时间 | **23:53:18 +08**（curl 启动）/ 落盘 mtime **23:54:29 +08** / web_fetch **15:54:55Z** |
| 间隔 | 清单比官方材料早 **≥ 66 秒**（与基准 #1 的 63 秒同量级） |
| 是否先读过 report | **没有。** 仓库自带 `Hybra-V12-output.md`（Zellic V12 AI 输出；README 明文"V12 findings 视为 OOS"）、`discord-export/`、`audit/` 全程**未读** |
| 唯一"非源码"输入 | `scope.txt` / `out_of_scope.txt` / `README.md`（= 程序事实/范围，属允许） |

**结论: 盲测纪律遵守（清单先落盘，mtime 可复核）。** 局限见 §6。

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

- **回读核对:** `sloc.sh --list` = **14 行**（= `scope.txt` 14 条 ✓）；`--total` = **4045**。
- **与官方不可比:** 官方报告写 **"3,846 lines of Solidity code"**（口径未定义）。⇒ **4045（我们） vs 3846（官方）不可混用**，两者并列展示。
- **机械三连:** 谱系 = **Solidly/Blackhole(ve33)** + **Uniswap-V3(cl)** 混合分叉（`synthetix-staking 15 · openzeppelin 9 · uniswap-v2 6 · uniswap-v3 5 · curve-stableswap 2 · masterchef 1`）。上游 Blackhole **不在本仓**（shallow clone，1 commit）⇒ 差分优先读无从下手，全量通读 14 文件。

---

## 2. 我们的盲测清单（读官方 report **之前**落盘）

**落盘物:** `bench/BLIND_LIST_hybra-2025-10.md`（**104 行**，mtime 23:53:12 +08）。共 **12 条候选 + 8 条 negative**。

| # | file:line | 机制（一句话） | 我们给的严重度 | 可达性依据 | 事后自评 |
|---|---|---|---|---|---|
| **B-01** | `GovernanceHYBR.sol:137`+`:144` | `deposit()` 先把 HYBR 锁进 veNFT 再 `calculateShares(amount)` ⇒ 份额按"事后" `totalAssets` 算 ⇒ 后续存款人被稀释 | **H** | 无权限 `deposit()` | ✅ **命中官方 H-01**（连严重度都给对） |
| **B-02** | `GovernanceHYBR.sol:191`+`VotingEscrow.sol:1169` | 赎回拆三段喂 `multiSplit`；`remaining/fee` 可能为 0 ⇒ `require(amounts[i]>0,"ZW")` revert ⇒ 无法全额退出 | M | 任意 gHYBR 持有人 | 未被官方 H/M 收录 |
| **B-03** | `VotingEscrow.sol:1153-1200` | `multiSplit` 逐项向下取整（Σ子<父）+ burn 不移 `permanentLockBalance` | M/L | 需 `canSplit` | 未被官方收录 |
| **B-04** | `VoterV3.sol:211`+`:158`+`VotingEscrow.sol:833/888` | 权重衰减后 `poke` 里 `_poolWeight` 取整为 0 ⇒ `require(...,"ZV")` revert ⇒ 该 NFT 无法再 deposit_for/increase_amount/merge | **M** | 任意投票过的 veNFT，仅随时间 | ✅ **命中官方 M-04**（机制一字不差） |
| **B-05** | `VoterV3.sol:141-143/217-219` | `_reset/_vote` 取**当前** bribe 地址；GAUGE_ADMIN 换 bribe ⇒ 旧 deposit 被弃、账目静默错位 | M | 需 GAUGE_ADMIN 换 bribe | 未被官方收录（判据 2 产物） |
| **B-06** | `GaugeManager.sol:330-338 / 138-150 / 282-296 / 477-490` | 批处理"单条 revert ⇒ 整批回滚"（**判据 1**） | M/L | 无权限入口 | ⚠️ **是官方 M-09 / QA-L-01 的影响机制**（非独立条目） |
| **B-07** | `GaugeManager.sol:470-475` | `claimRewards(address[],uint8)` 硬转 `IGauge`，对 CL gauge 无对应 selector ⇒ 整批 revert | L | 无权限 | 未被官方收录 |
| **B-08** | `GaugeManager.sol:373-397` | 零权重 gauge 被抬 `supplyIndex` ⇒ 已累积 `_delta` 静默作废、emission 滞留 | M | 无权限 | 未被官方收录（与 M-05 同族"奖励滞留"） |
| **B-09** | `DynamicSwapFeeModule.sol:169-172` | swap 费折扣按 `tx.origin` 匹配 | L | 任意 swap | 未被官方收录（M-01 是费用域但根因不同） |
| **B-10** | `RewardHYBR.sol:260-277` | `amount==0` revert（破坏 ERC20 语义）+ 转账钩子内写 `exempt.add(from)` | L | 任意 rHYBR 转账 | 未被 H/M 收录；⚠️ **对应官方 QA `L-06 transferFrom() breaks erc20 compliance`** |
| **B-11** | `GovernanceHYBR.sol:492-511` | `receivePenaltyReward` **无权限检查**，可强行 lock gHYBR 的 HYBR / 污染 `penalty` 记账 | M/L | 任意地址 | ✅ **命中官方 M-03**（官方把此函数列为攻击入口并建议加权限） |
| **B-12** | `RewardHYBR.sol:138-154` | `gHYBR` 未 set 时 TO_HYBR 赎回 revert（配置依赖可用性） | L | 任意 rHYBR 持有人 | 未被官方收录 |

**negative（主动排除，8 条）:** 见 BLIND_LIST 原文（`index/weights` 同 tx 一致性、`CLPool` fee 三段和、1 wei 哨兵、`GaugeV2.maturityTime` 死代码、`setScalingFactor`+`getFee` 上限、`HYBR` unchecked 加法、`GaugeCL.deposit` 池校验、`attachments/voted` 守卫）。

---

## 3. 官方 10 条（1H + 9M）

| 编号 | 一句话 | 官方锚点 |
|---|---|---|
| **H-01** | `GovernanceHYBR.deposit` 先 `deposit_for` 再 `calculateShares` ⇒ 新存款按事后 `totalAssets` 计份额、铸得太少（自付滑点），价值转移给先存者 | `GovernanceHYBR.sol#L137-L144` |
| **M-01** | `CLFactory.getSwapFee` 丢弃 >100_000 ppm(10%) 的动态费并**静默**回落到 tick-spacing 默认（~0.05%），而模块允许到 50% ⇒ 治理以为高费在生效 | `CLFactory.sol#L176-L189` |
| **M-02** | `GaugeV2.emergencyWithdraw` 缺 `updateReward` ⇒ 用户清零余额后 `earned()` 归零，**已累积未登记的奖励全丢**且滞留在 gauge（sponsor disputed） | `GaugeV2.sol#L270-L281` |
| **M-03** | gHYBR "首存攻击"：`deposit` 不检查"份额 > 0"，配合**无权限的 `receivePenaltyReward` 捐赠**抬高 `totalAssets` ⇒ 后续存款人被舍入为 0 份额、资产被吞 | `GovernanceHYBR.sol#L144 / #L492-L509 / #L238` |
| **M-04** | 对某池投 1 wei 灰尘票：衰减后 `_poolWeight` 取整为 0 使 `poke()` 恒 revert ⇒ 该 veNFT **不可 poke**，可长期保留满额票权（破坏 W 不变量；sponsor disputed） | `VoterV3.sol#L208-L211` |
| **M-05** | `GaugeCL.notifyRewardAmount` 用 `rewardAmount/epochTimeRemaining` 作 `rewardRate`，**忽略 rollover** ⇒ reserve 对、费率过低 ⇒ rollover 永发不出，下个 epoch 被 `syncReward` 覆盖抹除 | `GaugeCL.sol#L256` |
| **M-06** | `GaugeCL._claimFees` 按"gauge 全部余额"而非"本次 `collectFees()` 增量"转账 ⇒ 当 rewardToken == token0/token1 时，**任何人可把当期质押奖励当手续费扫给 internal_bribe**（+后续 notify DoS） | `GaugeCL.sol#L304-L335` |
| **M-07** | `GovernanceHYBR.claimRewards` 用 `IVoter.poolVote(veTokenId)` 取"整个地址数组"——Solidity 自动 getter 只接受 `(id,index)` ⇒ 该调用**恒 revert**，claim 功能完全不可用 | `GovernanceHYBR.sol#L370` |
| **M-08** | 同一交易内 `create_lock` + `increase_amount`：`_checkpoint` 在同一时间戳写入两个 user_point ⇒ 该时刻投票权计算错误 | `VotingEscrow.sol#L760` |
| **M-09** | `GaugeManager._createGauge` 对 CL gauge 不校验 pool 是否出自可信工厂（该检查被注释"removed due to code size"）⇒ 恶意"池"通过白名单即可建 gauge，投票后 `updateRewardsGrowthGlobal()` revert **永久砖化分发**（也由 V12 命中） | `GaugeManager.sol#L165-L201` + `GaugeCL.sol#L239-L246` |

---

## 4. 对比表：命中 / 漏 / 假阳性

### 4.1 主指标（分母非退化 —— 这是与基准 #1 的本质区别）

| 指标 | 值 |
|---|---|
| 官方 H+M 总数 | **10**（1H + 9M） |
| 我们**严格**命中（机制与我们的主诉一致） | **2**（H-01 ← B-01；M-04 ← B-04） |
| 我们**含部分**命中（机制被官方点名为根因/入口） | **3**（+ M-03 ← B-11） |
| **命中率** | **2/10 = 20%**（严格）· **3/10 = 30%**（含 1 条部分命中） |
| 我们提出的候选总数 | **12**（B-01…B-12） |
| 被官方 H/M 收录 | **3** |
| **假阳性率 = 官方未收录 / 我们提的总数** | **9/12 = 75%**（其中 B-10 出现在官方**已公开的 QA** L-06 ⇒ "完全无着落"的约 **8/12 ≈ 67%**） |
| QA 缺口 | 官方 QA 共 **45 份报告**，**正文只收录 1 份（rayss，L-01…L-08 + I/NC）** ⇒ 我们另 9 条**无法排除**躺在未公开的 44 份里 |

### 4.2 逐条「为什么漏」（9 条未命中 / 缺失官方条目）

**官方有、我们完全没提（5 条）：**

| 官方 | 漏因归类 | 说明 |
|---|---|---|
| M-02 (`GaugeV2.emergencyWithdraw`) | **缺判据（"清零余额前先 settle 累积"）** | 我们**读了** `emergencyWithdraw`，但没把它与 `updateReward` 缺失串起来；这是"记账口径 vs 余额口径"缺一条判据 |
| M-05 (`GaugeCL` rollover) | **需会计恒等式建模** | 我们**读了** `notifyRewardAmount` 甚至看到 `rollover`，但没建 `reserve == rate×duration` 的守恒式 ⇒ 没发现 rate 漏算 rollover |
| M-06 (`GaugeCL._claimFees`) | **需"同名资产碰撞"建模** | 我们**读了** `_claimFees`，没考虑 `rewardToken ∈ {token0,token1}` 这一常见碰撞 |
| M-07 (`GovernanceHYBR.claimRewards`) | **缺"跨合约 getter ABI 核对"判据** | 我们**读了** `claimRewards`，但对 `IVoter.poolVote(id)` 的 getter 语义**未回读接口定义**（该接口 OOS）⇒ 漏 |
| M-08 (`VotingEscrow._checkpoint`) | **需 ve checkpoint 数学** | 我们**读了** `_checkpoint`，但"同块两次 checkpoint 的 user_point"属我们已承认的弱项（ve 数学） |

**官方有、我们提了但机制没落到那个点（0 条计入）：**
- M-01（费用域）：我们提的是 `tx.origin` 折扣（B-09），官方是 **cap 不匹配的静默回落** ⇒ **擦边不中**。

**我们提了、官方 H/M 未收录（9 条）：** B-02/B-03/B-05/B-06/B-07/B-08/B-09/B-10/B-12。
- 其中 **B-06** 不是"错"：它正是官方 **M-09 / QA-L-01** 的**影响机制**（单条坏元素 ⇒ 整批回滚）。
- 其中 **B-10** 命中官方**已公开 QA** 的 `L-06`。
- 其余多为**低档一致性/可用性**（L 档噪音偏高），与我们基准 #1 的画像一致。

### 4.3 域归类 —— 官方 10 条落在谁的域？

| 域 | 官方条目 | 条数 |
|---|---|---|
| **我们的族（记账 / 份额 / ve 与奖励记账）** | H-01、M-02、M-03、M-04、M-05、M-06、M-08 | **7** |
| 其它域（配置一致性 / ABI-可用性 / 输入校验-不可信调用） | M-01、M-07、M-09 | **3** |

> **结论（关键）：这次**多数（7/10）属于我们的域** ⇒ 命中率**不能**用"域不贴"来解释。**
> 我们在**自家域内**的召回 = **3/7 ≈ 43%**（严格 2/7 ≈ 29%）——即 **4 条在域内的真问题被漏（M-02/M-05/M-06/M-08）**。
> ⇒ 本次 30%(含部分)/20%(严格) **可归因于能力（域内方法学不完整）**，而非工具错配或域不贴。这是与基准 #1 相反的归因方向。

---

## 5. §3.5 两条新增判据 —— 逐条检查结论（**单列，任务书硬要求**）

### 判据 1：批量操作的部分失败（单条无效是否导致整批回滚）—— **成立，且被官方间接确认**
- **我们在靶上的检查:** **命中**。`GaugeManager.distribute(address[])`（`:330-338`）、`distributeFees()`（`:282`）、`distributeFees(start,finish)`（`:291`）、`createGauges()`（`:138`）、`claimRewards()/claimAllRewards()`（`:470/:483`）、`CLFactory.collectAllProtocolFees()` 全部是"循环 + 单条 revert ⇒ 整批回滚"。落成 **B-06**。
- **官方对应:** 判据直接对应两条官方条目——**M-09**（"a malicious pool can revert and permanently **brick emissions distribution** once voted"，砖化的正是 `distributeAll` 这批）与**已公开 QA `L-01 Permanent Denial of Service in collectAllProtocolFees()`**（循环 `allPools`，一个坏池全批失败）。
- **结论:** **判据 1 成立且高价值** —— 它把我们引到了官方 M-09 的影响机制（虽未引到根因"缺 pool 校验"）。**保留并升级**：应把"批处理 + 单条失败"与"循环内调用**不可信外部合约**"合并成一条前置判据（后者才是 M-09 的根因）。

### 判据 2：跨函数状态生命周期耦合（一个函数改状态 ⇒ 另一函数先前凭据静默失效）—— **部分成立 / 本次未直接命中 H/M**
- **我们在靶上的检查:** **命中 2 条候选** —— B-05（换 bribe ⇒ 旧 deposit 静默作废）、B-08（零权重抬 `supplyIndex` ⇒ 已累积 `_delta` 作废）。
- **官方对应:** 这两条**均未被官方 H/M 收录**。但该判据的"生命周期"形态在官方有**弱对应**：**M-05** 的 rollover 在下一 epoch 被 `syncReward`（`delete rollover`）覆盖抹除 = "先前累积凭据被后续状态更新静默作废"。
- **结论:** 判据 2 **结构性成立**（本次未产出官方 H/M 命中），但其"跨 epoch 状态被覆盖"这一子形态**可加固**为：*"任何 `delete`/覆盖型状态更新，是否会让上一周期已累积但未提取的权益永久消失？"*（正是 M-05 的形状）。

---

## 6. 诚实局限（≥3 条）

1. **限时 30 分钟 vs 竞赛 10 天**：官方 H-01 有 **34 位 warden** 独立命中。我们的 30 分钟单人阅读与全社区数万人时不可比；30% 这个数字**上限约束在时间盒**，不是工具天花板。
2. **未做任何可执行验证**：12 条候选**全部止于静态阅读**，无 PoC、无 fork 不变量（VPS 512MB 不适合 foundry）。官方要求 H/M 必须带可运行 PoC ⇒ 我们**即使方向对也不满足提交门槛**（如 B-01 我们给 H，但没有 PoC）。
3. **未读 `discord-export/` / `audit/` / `Hybra-V12-output.md`**：这三个是仓库自带材料（V12 明文 OOS）。**保守起见全程未读**以保盲测纯净 ⇒ 我们放弃了"V12 已命中 M-02/M-05/M-09"这类**免费线索**，这是**主动选择**而非能力限制。
4. **QA 缺口**：官方 QA = **45 份报告**、正文只公开 1 份（rayss）。「假阳性 75%」只在**官方正文 H/M**口径成立；我们的 B-02/B-03/B-05/B-06/B-07/B-08/B-12 **无法排除**落在未公开的 44 份里。
5. **上游差分缺失**：本靶是 Blackhole 分叉，README 明文"Blackhole 已确认的问题不算，除非 delta 加重了影响"。我们能看到的**唯一一处 delta 注释**（`_createGauge` 里被删掉的 pool 校验）恰恰是官方 **M-09**——**我们读到了那一行却没识别它**（见 §6.6）。
6. **最重要的自省（不是局限，是教训）**：9 条未命中里 **5 条（M-02/M-05/M-06/M-07/M-08）我们"读过那段代码"**，M-09 更是**逐字读过被注释的校验行**。⇒ 本次**不是覆盖不足（14/14 文件全读、SLOC 100%）**，而是**"读到了但没建立起跨点连接"**：既缺"两处对读"（M-01/M-06/M-07），也缺"会计恒等式"与"ve/CL 数学"两类**建模判据**（M-05/M-08）。**这与基准 #1 的两条漏因同型（判据缺失），只是补丁点不同。**

---

## 7. 不确定项（单列，不进结论）

| 项 | 为什么不进结论 |
|---|---|
| `sloc.sh 4045` vs 官方 `3,846` | 官方口径未定义（可能计 nSLOC 或含/不含 OOS 引用），**不做换算**，两者并列。 |
| 官方代码来源 commit 不一致 | 报告 Scope 写 `hybra-finance/hybra-finance@480cb4ee`，而 blob 链接用 `66c42f3c` / `6299bfbc`（C4 仓）；行号可能因版本而偏移。我们以**本机 clone 的 main** 为准，所有 `file:line` 均在本机回读确认存在（12/12 候选锚点均可解析）。 |
| B-11 → M-03 算不算"命中" | 官方 M-03 主诉是"deposit 未检查 0 份额"，把 `receivePenaltyReward` 列为**攻击入口**并建议加权限；我们 B-11 提的正是"无权限 `receivePenaltyReward`"。严格算**部分命中**（我们没提"0 份额截断"）。所以给出 **2/10 与 3/10 两个数**。 |
| `HybraTimeLibrary.WEEK = 1800`（测试网） | in-scope 文件引用该库常量，但库本身 OOS；若主网部署改用注释里的 `7*86400`，时间窗/奖励语义会变。不影响本次对比主结论。 |
| 官方 M-02 / M-04 被 sponsor **disputed** 但**仍计入 10 条** | 以官方报告页口径为准（计入 H+M=10）。 |

---

## 8. 一句话结论（给未来的自己）

> **本次分母是真的（H+M=10），命中率 = 2/10（严格）或 3/10（含 1 条部分命中），假阳性 9/12。**
> **最有价值的两个信号：① 我们给的"最强候选"B-01 精确命中官方唯一的 H-01，且严重度也给对——说明"记账/份额"这条主线是真本事；② 9 条漏里 5 条是"读到了但没连接"、M-09 是"逐字读到被注释的校验却没识别"，且官方 10 条里 7 条本就落在我们域内 ⇒ 差距在**域内方法学（对读 + 会计恒等式 + ve/CL 数学）**，不在"域不贴"、也不在"读得不够多"。**
> **下一步补丁（可执行）:** ① 判据 1 升级为"批处理 × **不可信外部调用**"（M-09 根因）；② 判据 2 增子条"**覆盖型状态更新**是否让上周期累积权益永久消失"（M-05 形状）；③ 新增"**同名资产碰撞**"判据（M-06）；④ 新增"**跨合约 getter/ABI 核对**"判据（M-07）；⑤ 把"**cap 两端不匹配**"（M-01）纳入配置一致性扫描。
