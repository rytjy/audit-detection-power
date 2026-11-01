# BENCHMARK — C4 `2025-11-megapot`（自我基准 #4 · 月度盲测）

- **跑测人:** 桑多涅（子线程 blind self-benchmark #4，isolated context）
- **日期:** 2026-10-01（T0 15:29 → 交付 15:36 +08，盲测用时 ~7min 净读；时间盒 60min 内）
- **靶:** C4 contest `2025-11-megapot`（lottery / jackpot 协议 · Solidity）
  - 版本: `code-423n4/2025-11-megapot` @ `f0a7297d59c376e38b287b2c56740617dbbfbdc7`（VPS `codeload` 抓取）
  - 原始 tarball sha256 `48ea974b…5b6a67` → 消毒后 `megapot_clean.tgz` sha256 `9cfcf742…b2ac7`（212,459 B）
  - in-scope **16 文件 / 2,562 SLOC**（`hunt-kit/scripts/sloc.sh` 口径）；子线程自报读完 4401 SLOC/16 文件（100% 覆盖，SLOC 差异因口径含注释/空行）
- **官方结论（原文）:** *"aggregated total of **11** unique vulnerabilities"* → **3 High + 8 Medium**
- **官方来源:** https://code4rena.com/reports/2025-11-megapot （VPS curl 落盘 5,149,708 B；本机副本 mtime 2026-10-01 15:40+08）

---

## 0. 盲测纪律（自述 + 父线程复核）

| 检查 | 结果 |
|---|---|
| 先出清单 → 落盘 → 之后才读官方 | ✅ `CANDIDATES.md` mtime **15:36:34** · `FREEZE.md` **15:37:05** · 官方材料抓取 **15:37+** |
| 分母预验（仅计数） | ✅ 15:2x 只取 `aggregated total of 11`，未读正文 |
| 消毒 | ✅ 删 `2025-11-megapot_V12.md` · `4naly3er-report.md` · `Megapot v2 - Zellic Audit Report.pdf`；**从未下载** `-findings` 仓 |
| 隔离 | ✅ 子线程 run `b8a2c754`（context=isolated，无网络、无 findings） |
| 锚点复核（父线程 L-GATE） | ✅ 抽验 5 处 `file:line` 全部逐字存在（`Jackpot.sol:581/1496` · `JackpotBridgeManager.sol:178/268/225`） |

---

## 1. 官方 11 条（3H + 8M）

| 编号 | 一句话 | 域 |
|---|---|---|
| **H-01** | `JackpotBridgeManager._bridgeFunds` 对**用户可控** `_bridgeDetails.to/.data` 发任意外部调用 ⇒ 攻击者用 `safeTransferFrom` 把桥托管的（他人）NFT 偷走（`onERC721Received` 内拉走授权 USDC 骗过余额校验） | 不可信外部调用/资产窃取 |
| **H-02** | `TicketComboTracker.countTierMatchesWithBonusball` 子集匹配计数**未优化**，结算时超 Base 链 tx gas limit ⇒ 抽奖无法结算 | gas/DoS |
| **H-03** | `JackpotLPManager.processDrawingSettlement` 的 `newLPValue` **不复用 `_calculateLpPoolCap`** ⇒ 结算后 LP 池可超上限（`lpEarnings` 每期最多 +30%） | 记账/池子上限 |
| **M-01** | 活跃期内 owner 可改**全局配置**（`protocolFee`/`referralFee`/`payoutCalculator`/`entropy`/`jackpotLPManager`）⇒ 改变结算结果或导致结算失败 | 管理/配置生命周期 |
| **M-02** | `JackpotBridgeManager` 取**全局** `ticketPrice()` 而非当期快照 ⇒ 期中改价：**涨** ⇒ 用户多付且差额**卡死**在桥（无 sweep）；**跌** ⇒ approve 不足、`buyTickets` revert（DoS） | 记账/价格快照 |
| **M-03** | `setLPPoolCap` 要求新上限 ≥ 当前 `lpPool + pendingDeposits` ⇒ LP 只要猛存钱就能**阻断**治理参数更新（`setNormalBallMax`/`setGovernancePoolCap`/`setLpEdgeTarget`/`setReserveRatio` 全部经此路径） | 管理/配置 DoS |
| **M-04** | 紧急模式不可退出 ⇒ 期内 `referralWinShare` 仍被记入 `drawingState.lpEarnings`，但 `runJackpot` 被 `noEmergencyMode` 挡住 ⇒ 这些 **lpEarnings 永久滞留** | 记账/滞留 |
| **M-05** | `ScaledEntropyProvider` 用**同一个** seed 生成 normal balls 与 bonus ball；当 `normalballMax == bonusballMax` 时 bonus ball 必落在 normal 集合内 ⇒ 中奖率被放大 `(bonusballMax/5)` 倍，可买all combos 稳赚 | 随机性 |
| **M-06** | `Entropy` 的 `sequence` 是**按 provider 地址分别计数**的 ⇒ 攻击者可抢跑 `setEntropyProvider`、伪造 `pending[s]`、把新 provider 的 sequence 推到 `s-1` 后自购票并 `runJackpot` ⇒ **锁定开奖结果** | 随机性 |
| **M-07** | 活跃期内换 entropy provider ⇒ 回调地址/sequence 失配 ⇒ **永久锁死** + 回调失败（judge 判为 S-365 的重复，为分credit单列） | 管理/配置生命周期 |
| **M-08** | 活跃期内换 payout calculator ⇒ 已结算未领取的奖金按新计算器取值 ⇒ **未领取奖金丢失**（judge 判为 S-365 的重复） | 管理/配置生命周期 |

---

## 2. 我们的清单（读官方**之前**落盘）

`CANDIDATES.md`（91 行 / 14,335 B / sha256 `555d317a…701fa`）：**7 条候选 = 0H / 3M / 4L**，另 13 条显式否定。

| # | file:line | 机制 | 我们给的档 | 官方归属 |
|---|---|---|---|---|
| **C-01** | `Jackpot.sol:581-601` | `emergencyRefundTickets` 烧票但不清 `drawingEntries` 追踪器；回调无 `noEmergencyMode` ⇒ 已退款的票仍被算作中奖票 ⇒ LP 池被扣、USDC 滞留（幽灵中奖票） | M | ⚠️ **部分** ↔ **M-04**（同"紧急模式资金滞留"影响类，**根因不同**） |
| **C-02** | `Jackpot.sol:1494-1497` | `uint8(...)` 静默截断 `newBonusball`（仓内有 `UintCasts.toUint8` 却未用）⇒ 位移 ≥256 ⇒ bonusball 位归零 ⇒ 档位判错/下溢。附带指出 `lpEarnings→newPrizePool` 不受 `lpPoolCap` 约束 | M(低置信) | ❌ 未收录（其"附带指出"擦到 **H-03** 的域，但主诉不同） |
| **C-03** | `JackpotBridgeManager.sol:178-184` | 桥用**全局** `jackpot.ticketPrice()` 而非当期快照 ⇒ 期中改价：多付且卡死 / approve 不足 DoS | M | ✅ **命中 M-02**（机制一字不差，含"卡死在桥 + 降价 DoS"两点） |
| **C-04** | `Jackpot.sol:591-592` | `emergencyRefundTickets` 用**当前** `referralFee` 而非购买时费率 ⇒ 退款金额错 | L | ⚠️ **部分** ↔ **M-01**（`referralFee` 期中可变是 M-01 明列的一项） |
| **C-05** | `Jackpot.sol:886-893` | `normalBallMax` 只校验 `uint8`：≤9 触发 `Combinations.choose` 的 `assert` ⇒ 结算永久 revert；>128 同理 | L | ❌ 未收录 |
| **C-06** | `JackpotBridgeManager.sol:225-243` | `claimWinnings` 不清理 `ticketOwner` ⇒ 后续 `claimTickets` 路径 DoS | L | ❌ 未收录 |
| **C-07** | `JackpotBridgeManager.sol:268` | `claimTickets` 缺 `nonReentrant`（自己有外部调用） | L | ❌ 未收录（自述"未证明可利用"） |

---

## 3. 三个数字

| 指标 | 值 |
|---|---|
| 官方 H+M | **11**（3H + 8M） |
| **严格命中** | **1**（M-02 ← C-03）⇒ **1/11 = 9.1%** |
| **含部分命中** | **3**（+M-01 ← C-04；+M-04 ← C-01）⇒ **3/11 = 27.3%** |
| 我们提出候选 | **7** |
| 被官方 H/M 收录 | **1 严格 + 2 部分** |
| **1−精确率**（精确率 = 命中/提交；**分母 = 提交阈值** = 达 H/M 档的提交；QA 未公开 ⇒ **上界**） | 分母=**阈值(3)**：严格 **2/3 = 67%**；含部分 **1/3 = 33%**<br>分母=**全部候选(7)**：严格 **6/7 = 86%**；含部分 **4/7 = 57%** |
| 严重度校准 | 我们最高只给 **M** ⇒ **3 条官方 High（H-01/H-02/H-03）一条没抓到**（严重度整体低估） |
| 覆盖 | in-scope 16/16 = **100%**（子线程自述 + 父线程锚点复核） |

### 域归类 —— 官方 11 条落在谁的域？

| 域 | 官方条目 | 条数 |
|---|---|---|
| **我们的族**（记账/份额/池子上限 + 配置生命周期） | H-03、M-01、M-02、M-03、M-04、M-07、M-08 | **7** |
| 随机性/entropy | M-05、M-06 | 2 |
| 不可信外部调用/资产窃取 | H-01 | 1 |
| gas/DoS | H-02 | 1 |

> 域内召回（我们的族 7 条）：严格 **1/7 ≈ 14%**；含部分 **3/7 ≈ 43%**。
> ⇒ 与 hybra 基准**同一结论**：**差距在域内方法学，不在"域不贴"**。

---

## 4. 逐条「为什么漏」

**官方有、我们完全没提（8 条）：**

| 官方 | 漏因归类 | 说明 |
|---|---|---|
| **H-01** (`_bridgeFunds` 任意外部调用) | **缺"不可信外部调用的 callee/target 是否用户可控"判据** | 我们**读了** `claimWinnings:225-243`（正是 H-01 的入口），却**没顺着它往下读 `_bridgeFunds`** 的 `_bridgeDetails.to/.data`。反而是 §3.5 判据 3（批处理 × 不可信外部调用）的同族——**判据在，没应用到这条调用链**。 |
| **H-02** (gas 超限) | **缺"复杂度/gas 上限"判据** | `TicketComboTracker` 我们**逐行读完**并判定"数学精确、无重复计数"（否定 #2）⇒ **只核了正确性，没核代价**。 |
| **H-03** (LP 池超上限) | **缺"上限在新路径是否被复用"判据** | 我们**读了** `processDrawingSettlement`（否定 #4），结论"deposit-at-NAV 自洽、无稀释" ⇒ **核了份额会计，没核池子上限不变式**。 |
| M-01 / M-07 / M-08 (期中改全局配置) | **缺"活跃期内可变配置 × 结算读取"判据** | 我们点到 `ticketPrice`（C-03）与 `referralFee`（C-04）两个实例，但**没有把"活跃期内所有可变全局量"当成一个模式**去系统性扫。 |
| M-03 (LP 存钱阻断参数更新) | **缺"治理路径自身的 DoS 面"判据** | 读过 `setLPPoolCap` 与 `processDeposit`，未把"新上限须 ≥ 当前池"读成攻击面。 |
| M-05 / M-06 (随机性) | **域外 + 未建模** | 我们对 entropy 只做了"回调地址强制 = msg.sender"的**否定**（否定 #5/#6），**没有检验 seed 复用与 sequence 跨 provider 复用**。 |

**官方有、我们擦边（2 条，计为部分）：** C-01 ↔ M-04（同"紧急模式资金滞留"，根因不同）；C-04 ↔ M-01（`referralFee` 期中可变是 M-01 明列项之一）。

**我们提了、官方 H/M 未收录（4 条）：** C-02、C-05、C-06、C-07（`C-02` 在 QA 层无法排除；官方 QA 未在本报告正文公开 ⇒ 缺口已标注）。

---

## 5. 与上期基线的对比（月度基线核心）

| 场次 | 日期 | 分母 | 严格命中 | 含部分 | 1−精确率（上界） | 覆盖率 |
|---|---|---|---|---|---|---|
| 2025-07-lido-finance | 09-27 | H+M=0（退化） | 0/2 Low | — | — | — |
| 2025-10-hybra-finance | 09-27 | **10** | **2/10 = 20%** | 3/10 = 30% | 9/12 = 75% | 100% |
| 2025-10-sequence | 10-01 | **6** | **1/6 = 16.7%** | — | 5/6 = 83% | 100% |
| **2025-11-megapot** | **10-01** | **11** | **1/11 = 9.1%** | **3/11 = 27.3%** | **阈值分母 2/3 = 67%（严格）/ 1/3 = 33%（含部分）**；全候选分母 86% / 57% | **100%** |

### 🔴 诚实结论：**严格口径退步了**
- **严格命中率 9.1% 是四次里最低**（hybra 20% → sequence 16.7% → megapot 9.1%）；含部分口径 27.3% 与 hybra 的 30% 基本持平。
- **退步的直接原因可定位**：这次分母里有 **3 条 High**，而我们**一条 High 都没给**；且 3 条 High 全部落在**我们读过并主动否定**的代码区（`_bridgeFunds` 邻域、`TicketComboTracker` 数学、`processDrawingSettlement` 会计）。⇒ 与 lido 基准同型的 **"读到未连接/读到判成非问题"**，这次是 **3 条全中该型**。
- **进步的一面**：1−精确率（阈值分母）从 sequence 的 83% 降到 **33%（含部分口径）**，且候选数收敛（7 条 vs 上次 12 条），**没有堆 L 档噪音**。
- **不能归因于"域不贴"**：官方 7/11 落我们族，域内严格召回 1/7。也不能归因"读得不够"：覆盖 100%。

### 可落地的判据补丁（来自本次真实漏点）
1. **外部调用的 target/calldata 是否用户可控** —— 顺着**任何**带外部调用的 claim/withdraw 往下读一层（H-01）。
2. **复杂度/代价** —— 对"循环 × 组合计数 × 内部数组"的结算路径，除正确性外必须问 **gas 上界**（H-02）。
3. **上限不变式在新路径是否复用** —— 凡有 `XxxCap`，检查**每条会改变被约束量的路径**是否都执行了该 cap（H-03）。
4. **活跃期内可变全局配置清单** —— 把"期初快照 vs 期读全局"做成一张对读表（M-01/M-02/M-07/M-08）。
5. **治理路径自身的 DoS 面** —— 参数设置函数里"必须 ≥ 当前值"的校验 = 可被外部操作阻断（M-03）。

---

## 6. 诚实局限（≥3 条）

1. **时间盒 7 分钟净读 vs 竞赛 10 天**：官方 H-01 有 12 位、M-01 有 **77 位** warden 独立命中 ⇒ 命中率数字受时间盒强约束，不等于工具天花板。
2. **未做任何可执行验证**：7 条候选全为静态阅读，**无 PoC / 无 fork**。megapot 官方所有 H/M **都带 hardhat PoC**（报告正文里就有），我们一条都没跑。
3. **依赖未核**：`lib/solady` 不在 checkout 内 ⇒ `ERC721` 的 `from==to` 自转 / `ownerOf` / `_burn` 语义**未本地验证**（影响否定 #9/#10）。
4. **QA 缺口**：官方 QA（Low/NC）未在本报告正文逐条公开 ⇒ "1−精确率" 只在 **官方正文 H/M** 口径成立（且因此只是**上界**），C-02/C-05/C-06/C-07 无法排除躺在未公开 QA 里。
5. **子线程自报 SLOC 4401 vs 我们口径 2562**：口径不同（含注释/空行），**不做换算**、两者并列。
6. **单次单人盲测**：只有 1 个隔离子线程，没有多人/多次重复 ⇒ 严格命中率 9.1% 的**噪声区间未估计**。

---

## 7. 一句话结论

> **分母是真的（H+M=11，3H/8M），严格命中 1/11（9.1%）· 含部分 3/11（27.3%）· 1−精确率（阈值分母）2/3=67%（严格）/ 1/3=33%（含部分）。**
> **最强候选 C-03 精确命中官方 M-02；但 3 条 High 全部落在我们"读过并主动否定"的区域（`_bridgeFunds` 邻域 / 组合计数 gas / LP 池上限）⇒ 严格口径较上期退步，根因是"核了正确性/会计、没核代价与上限，且外部调用链没往下读一层"，不是覆盖不足（100%）也不是域不贴（7/11 在我们族）。**


---

## 8. 🔻 更正：退步的「归因」被推翻 + 判分口径不自洽（2026-10-01 22:xx · 魔鬼代言人复核）

**（一）归因错了 —— 我当晚写的「§3.6 第 4 问砍掉了 3 条 High」没有任何证据**

父线程逐行回读 `CANDIDATES.md` 复核 DA 的指控，**全部成立**：

| 官方 | 在否定清单里的真实位置 | 真实落盘理由 | 是 §3.6-Q4 吗 |
|---|---|---|---|
| **H-02** | 否定 #2（`TicketComboTracker._countSubsetMatches:145-171`） | *"Mathematically exact; **no double-count found**"*（**正确性**） | **否** |
| **H-03** | 否定 #4（`processDrawingSettlement:371-392`） | *"deposit-at-NAV is self-consistent… **No accumulator/dilution exploit found**"*（**会计**） | **否** |
| **H-01** | **不存在** | 从没写成候选（"读了入口却没往下读一层"） | **否** |

- `§3.6` 在 `CANDIDATES.md` 全篇只出现 **3 次**：行 5（抬头）· 行 54（solady caveat）· 行 58（用 **§3.6-3「只是配置」**，不是 Q4）。**Q4 命中 0 次。**
- ⇒ 本文件 §4/§7 的漏因（"缺判据：gas 上界 / cap 复用 / 外部调用链往下读"）**才是对的**；当晚 22:07 写进 doctrine 的"闸门害的"是**从结论反推的叙事**，与证据相反。
- ✅ 已处置：`BOX_TEMPLATE §3.6 平台开关` 保留（依据改为**平台规则**），但**撤掉 megapot 因果**并写明更正。

**（二）判分口径不自洽（同类不同判）**

- C-02 候选的**附带说明**原文写的是：「`lpEarnings`(and hence `newPrizePool`) **is not capped by `lpPoolCap`**」——**这正是官方 H-03 的机制**。
- 但本文件把 C-02 记成 **❌ 未收录（"擦到 H-03 的域，但主诉不同"）**；同时 C-01↔M-04、C-04↔M-01 却按"影响类相同"记了**部分命中** ⇒ **同一场、同一份清单、两套判法**。
- ⇒ **按明示后的规则**（"候选里**任一条断言**命中官方机制即计部分命中，不只看主诉"）：**C-02 应计部分命中** ⇒ **含部分 = 4/11 = 36.4%**（> hybra 的 30%）。
- ⚠️ **诚实边界**：这条规则是**事后**写的（事前未冻结）⇒ 该重判**只能作为"口径敏感性分析"**，**不得**当作"其实我们更好"的证据。

**（三）"退步"未做稳健性检验**

| 口径 | 1/11（megapot） | 1/6（sequence） | 2/10（hybra） |
|---|---|---|---|
| Wilson 95% CI | (1.6%, 37.7%) | (3.0%, 56.4%) | (5.7%, 51.0%) |

- 三个区间**完全重叠**；1/11 与 2/10 之间**只差 1 个命中事件**。
- 跨靶比较还同时变了：**分母**（10/6/11，High 占比 10%/33%/27%）· **靶域** · **时间盒**（~30min vs ~7min 净读，4 倍）· **读者**（每场一个全新隔离线程，方差未标定）· **判分规则未冻结**。
- ⇒ **可以写**："严格 H+M 口径下 megapot 的命中数是四次里最低。"
- ⇒ **不可以写**："我们的能力退步了。"（未做稳健性检验的因果句）

**（四）结论（替代 §7 的第 2 句）**

> 严格口径下 megapot 命中 **1/11**（四次最低）；但**这个比较未做稳健性检验**（CI 全重叠、跨靶变量过多、判分规则事后才明示），**不能支撑"能力退步"这种因果结论**。
> 唯一可定位的**事实**是：3 条 High 全部落在我们**读过并主动否定**的区域 —— 而**否定的理由分别是"正确性"与"会计"，不是任何闸门**。⇒ 修正方向是 §3.5 的判据 9（gas 上界）与 10（cap 复用），**不是 §3.6**。
