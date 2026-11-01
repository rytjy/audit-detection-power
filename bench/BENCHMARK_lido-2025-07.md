# BENCHMARK — C4 `2025-07-lido-finance` (Lido CSM v2) · 我们的第一次「自我基准」

- **跑测人:** 桑多涅（子线程 C4 self-benchmark, blind run）
- **日期:** 2026-09-27（T0 23:37 +08，交付 00:30 +08，用时 ~53min，时间盒 120min 内）
- **靶:** C4 contest `2025-07-lido-finance`（$103,500, 2025-07-16 → 08-11）
  - 代码: VPS `192.227.190.145:/tmp/bench/2025-07-lido-finance`（上游 commit `d63d123f…`）
  - 本机工作副本: `/root/defi-practice/bench/lido-2025-07/`
- **官方结论（原文）:** *"The C4 analysis yielded an aggregated total of **0 High and Medium vulnerabilities**. Additionally, C4 analysis included **8 reports** detailing issues with a risk rating of **LOW severity or non-critical**."*
- **官方来源:** https://code4rena.com/reports/2025-07-lido-finance （HTTP 200，2026-09-27T15:43:40Z 抓取）
  - ⚠️ **任务书给的 `github.com/code-423n4/2025-07-lido-finance-findings` 不存在**：`git clone` 报 `could not read Username`，`api.github.com/repos/.../2025-07-lido-finance-findings` = **HTTP 404**；org 内 `search/repositories?q=org:code-423n4+lido` 只返回 `code-423n4/2025-07-lido-finance`（审计仓本身，无 findings）。改用 **code4rena.com 官方报告页**作为官方 findings 口径 —— 这是官方发布源，权威性不低于 findings 仓。

---

## 1. 范围（in-scope 清单 + SLOC）

**口径声明（避免 A6 型翻车）:**
- 我们的口径 = `hunt-kit/scripts/sloc.sh`（唯一口径）: in-scope `*.sol`，排除搜索根顶层 `lib/`、`*/node_modules/*`、`*/test/*`、`*/script/*`、`*/fixture/*`；计数非空非注释行。
- **回读核对:** `sloc.sh --list` 输出 **34 行**（= `scope.txt` 34 条，一致 ✓）；`sloc.sh --total` = **6967**。
- 官方 README 表: **34 个文件行**，官方汇总 **30 logic contracts / 5 interfaces / nSLOC = 5,896**。
- ⇒ **两口径不可比**（官方 nSLOC 口径未在仓库中定义，差异 ≈1,071 行）。本报告两个数字都列，**不混用**。

**in-scope 文件（34）** — 全部位于 `src/`：
```
CSAccounting.sol  CSEjector.sol  CSExitPenalties.sol  CSFeeDistributor.sol  CSFeeOracle.sol
CSModule.sol  CSParametersRegistry.sol  CSStrikes.sol  CSVerifier.sol
PermissionlessGate.sol  VettedGate.sol  VettedGateFactory.sol
abstract/{AssetRecoverer,CSBondCore,CSBondCurve,CSBondLock,ExitTypes}.sol
lib/{AssetRecovererLib,GIndex,NOAddresses,QueueLib,SSZ,SigningKeys,TransientUintUintMapLib,Types,UnstructuredStorage,ValidatorCountsReport}.sol
lib/base-oracle/{BaseOracle,HashConsensus}.sol
lib/base-oracle/interfaces/{IConsensusContract,IReportAsyncProcessor}.sol
lib/proxy/OssifiableProxy.sol
lib/utils/{PausableUntil,Versioned}.sol
```
**最大文件（行数）:** CSModule 1636 · HashConsensus 1258 · CSParametersRegistry 793 · CSAccounting 678 · BaseOracle 472 · VettedGate 422 · CSVerifier 408。

**读码前机械三连（`box_triage.sh`）结果:** 谱系指纹命中 `openzeppelin 8` / `uniswap-v3 2`（假命中）/ `proxy-eip1967 1` / `erc4626 1`；`primitive_scan` 总命中行 **3766**。
**结论: 本靶不是 DeFi 原语分叉，谱系差分无从下手**（真正的差分对象是 CSM v1，仓库为 shallow clone 只含 1 个 commit，无法本地 diff）⇒ 只能全量通读 34 文件。

---

## 2. 我们的盲测清单（读官方结论**之前**落盘）

**落盘物:** `/root/defi-practice/hunt-kit/bench/BLIND_LIST_lido-2025-07.md`（132 行）
**落盘时间:** **2026-09-27 23:42:37 +08**（`stat` 读数）
**官方报告抓取时间:** **2026-09-27T15:43:40Z = 23:43:40 +08** ⇒ 晚于盲测清单 **63 秒**。

| # | file:line | 机制（一句话） | 我们给的严重度 | 可达性依据 | 事后自评 |
|---|---|---|---|---|---|
| B-01② | `src/CSFeeDistributor.sol:106` | 无角色校验的 `reinitializer(2)` 抢先写 `rebateRecipient` | **H** | 需代理部署与 initialize 非同笔 | 与官方 0 条重合 |
| B-01① | `src/CSModule.sol:158` | 同上；抢先占用 reinitializer 槽 ⇒ `initialize` 永久 revert（砖化） | M | 同上 | 未证实 |
| B-02 | `src/CSFeeOracle.sol:80` | 无权限 `finalizeUpgradeV2(consensusVersion)` 抢跑 → DAO 那笔 revert | M | v1→v2 升级窗口 | 未证实 |
| B-03 | `src/abstract/CSBondCore.sol:183-192` | `_claimWstETH` 用 **wstETH 数额** 与 **stETH shares** 直接比较（单位错配） | M | 无权限，NO owner 自调 | 与官方 0 条重合 |
| B-04 | `src/CSModule.sol:587` | `migrateToPriorityQueue` 无调用者授权，第三方可消耗 NO 一次性迁移权 | M | 任意地址 | 与官方 0 条重合 |
| B-05 | `src/CSExitPenalties.sol:60/93/131` | 罚金表不校验 pubkey 属于该 NO | M/L | 需 STAKING_ROUTER_ROLE | 与官方 0 条重合 |
| B-06 | `src/CSFeeDistributor.sol:176-186` | 空报告把上一轮 treeRoot/treeCid 写进历史 | L | oracle 正常路径 | 与官方 0 条重合 |
| B-07 | `src/CSModule.sol:914` | `unchecked` 内 `enqueuedCount -= keysInBatch`，不变量破坏会静默回绕 | 待核 | 未构造 | 未证实 |
| B-08 | `src/CSAccounting.sol:352` 区 | `pullFeeRewards` 不受 `whenResumed` 约束 | L | 任意地址 | 与官方 0 条重合 |
| B-09 | `src/VettedGate.sol:380-393 / 258-290` | 推荐计数不校验 referrer 资格，与领取资格无共同校验点 | L | 需多白名单成员 | 区域与 L-02 同文件，机制不同 |
| B-10 | `src/CSStrikes.sol:127` | 判为 **negative**（只留意了罚金幂等，未发现批量 revert 问题） | L/非问题 | — | **同一函数就是官方 L-01，我们判反了** |

+

**主动排除项（negative results，7 条 N-1…N-7）:** 见 BLIND_LIST 原文（`enqueuedCount` 检查过减法、`getNodeOperatorSummary` 不可能下溢、`removeKeys` 不会错位已提取 key 指针、重复提交提取被拦、`_getQueue` 覆盖 legacy 优先级的边界、`_consume` 一次性、`CSAccounting.finalizeUpgradeV2` 全新代理上会 revert）。

---

## 3. 官方 findings 清单（H/M + 披露的 Low）

**H + M 总数 = 0**（官方 Summary 原文：*aggregated total of 0 High and Medium vulnerabilities*）。

**Low/Non-critical = 8 份 QA 报告**，但**官方报告正文只逐字收录了评分最高的那一份（won, S-305）的 2 条**；另外 7 份（0xAura S-599 · Ahmerdrarerh S-120 · K42 S-170 · madxcyber S-45 · MakeIChop S-97 · Sparrow S-618 · Teycir S-55）**正文未披露内容**。

官方正文披露的条目：

| 编号 | 一句话 |
|---|---|
| **L-01** | `CSStrikes.processBadPerformanceProof` 批量弹出「全或无」：任一条目 strikes < threshold 时 `_ejectByStrikes` 硬 revert，整批（含合法条目）回滚，需链下过滤后重提。 |
| **L-02** | `VettedGate` 赛季中 `setTreeParams` 换 root 后，旧 proof 全部失效（即使地址仍在新树中），必须给所有合格者重新分发 proof。 |

---

## 4. 对比表：命中 / 漏掉 / 假阳性

### 4.1 对 H+M（主指标）

| 指标 | 值 |
|---|---|
| 官方 H+M 总数 | **0** |
| 我们命中 | **0** |
| **命中率 = 我们命中 / 官方 H+M 总数** | **0 / 0 = 不可定义（分母为 0）** |

> ⚠️ **这是本次基准最重要的发现：这份考卷没有 H/M 题目。** 用 H+M 命中率来度量我们的工具能力，在此靶上是**退化（degenerate）的**，不能据此说"我们命中率 100%"或"0%"。
> 唯一可解释的说法: **官方 H+M = 0 ⇒ 我们没有漏掉任何 H/M** —— 但这是空条件成立，不构成能力证据。

### 4.2 对官方正文披露的 Low（次指标，唯一可算的分母）

| 指标 | 值 |
|---|---|
| 官方正文披露条目 | **2**（L-01, L-02） |
| 我们命中 | **0** |
| **命中率** | **0 / 2 = 0%** |
| 我们提出条目总数 | **10**（B-01…B-10） |
| 其中被官方收录 | **0** |
| **假阳性率 = 官方未收录 / 我们提的总数** | **10 / 10 = 100%** |

> ⚠️ 假阳性率必须带基数解读：分母是「官方**正文披露**的条目（2 条）」，不是「全部有效 issue」。另外 7 份 QA 报告未公开，**我们无法排除自己某条正躺在未披露的 QA 报告里**（见 §5 局限 3）。

### 4.3 逐条「为什么漏 / 为什么没中」

**漏掉 L-01（CSStrikes 批量全或无 revert）：**
- 我们**读过**这个函数（B-10 就是它），甚至写了 negative —— 但认的是「eject 与记罚金顺序/幂等」，**没有识别"单条不合格导致整批回滚"**。
- 漏因归类: **不是族覆盖不足**（函数在覆盖内、被逐行读过），而是**判据缺失**——我们的 checklist 缺「批量操作中单条失败是否应整批回滚」这一条 operational-DoS 判据；同时我们默认"链下会过滤"，未把它当缺陷。也说明**我们只盯资损与权限，不盯运营效率型缺陷**。
- 需要的知识: 无（不需要领域知识/链上数据）。⇒ **可修复的漏**。

**漏掉 L-02（赛季中换 root 使旧 proof 失效）：**
- 我们读过 `VettedGate` 全文并写了两条候选（B-09 关于推荐计数、N 系列关于 `_setTreeParams` 重复 root 校验），**但没把 `setTreeParams` 与 `claimReferrerBondCurve.verifyProof` 串成"赛季中途换 root 会作废既有 proof"**。
- 漏因归类: **跨函数状态耦合（root 生命周期 × proof 校验时点）未建模**；属于"设计/运营限制"类，我们的严重度模型里根本没有这一档。
- 需要的知识: 无。⇒ **可修复的漏**。

**假阳性 10 条的成因画像（诚实归因）：**
- 6 条（B-01x2/B-02/B-03/B-04/B-05）押在**「无权限的 reinitializer / 无授权的状态变更 / 单位错配」**——都是"看起来像洞"的**模式匹配**产物，**未做**：① 部署原子性验证（仓库无 `script/`，本靶未含）② CSM v1 上游对照（shallow clone 无法 diff）③ 可达性 PoC。
- 2 条（B-06/B-08）是**低级一致性/语义**，判给 L 合理，但官方没收 ⇒ 说明我们 L 档**噪音偏高**。
- 1 条（B-09）方向对（VettedGate 推荐）但**机制没落到官方那个点**⇒ 属"擦边不中"。
- 1 条（B-10）是**判反**（把问题当非问题）。

---

## 5. 诚实局限（≥3 条）

1. **事后测 vs 事前测（最大局限）**：我们**知道**这是 Lido CSM v2、**知道**官方公布结果前就已在各种语料里见过该审计的存在。虽然本次严格遵守"先落盘盲测清单（23:42:37）→ 才抓官方报告（23:43:40）"，且**未读** `4naly3er-report.md`、`test/`、`docs/`、`gist*`，但**无法排除过去训练语料里的间接记忆**影响候选生成。⇒ 本次只能称为"半盲（清单先落盘，但先验可能被污染）"。
2. **时间盒 53min vs 竞赛 26 天**：竞赛是全社区 26 天 × 数千人时的对抗性产出；我们单人 53 分钟。这个比值（≈ 1:1000+ 人力）本身就是结果的主要解释变量，**不能把 0/2 直接解读为"工具不行"**。
3. **官方只披露了 8 份 QA 报告中的 1 份**：另外 7 份（含 0xAura、K42、Sparrow 等）内容不公开，所以「假阳性率 100%」只在"官方**正文**"口径下成立；在"全部有效 issue"口径下**无法计算**。这是本次基准**最大的口径缺口**。
4. **H+M = 0 使主指标退化**：本靶不能用来做 H/M 命中率校准。要校准 H 档能力，必须换一个**官方有 H/M 的靶**（否则无论我们多强/多弱都得到同一个数）。
5. **未做可执行验证**：没有跑 `ov-harness`/fork 不变量、没有写任何 PoC（本靶 fork.just 需要 RPC+foundry，VPS 512MB 内存不适合）。⇒ 我们的 10 条候选**全部止于静态阅读**，"可达性"栏是推理不是证据。
6. **上游对照缺失**：CSM v1 → v2 的差分（本靶真正的"改动面"）因 shallow clone（仅 1 commit）无法本地做；B-03 这类"遗留缺陷"本可通过 `sibling_diff.sh` 秒判却做不到。

---

## 6. 不确定项（单列，不进结论）

| 项 | 为什么不进结论 |
|---|---|
| B-07 (`CSModule.sol:914` unchecked 下溢) | **未能构造**不变量破坏路径；`enqueuedCount >= keysInBatch` 在 `migrateToPriorityQueue` 实际实现下成立（注释描述的是被注释掉的替代版本）。挂"待核"。 |
| B-01 / B-02（未授权 finalize） | 成立与否**完全取决于部署原子性**，而本靶**不含 `script/`**，无法验证；Lido 实务多为原子部署 ⇒ 大概率不成立。 |
| B-03（wstETH 单位错配） | 代码在 CSM v1 已存在 ⇒ 可能是"已知/遗留"，官方可驳回；我们无 v1 源码可确认引入点。 |
| sloc 口径差（6967 vs 5896） | 官方 nSLOC 口径未定义；两个数都保留，不做换算。 |
| "官方 0 H/M"是否含 mitigation 轮次 | 只查到本次报告页，未见 mitigation 报告 ⇒ 以报告页为准。 |

---

## 7. 一句话结论（给未来的自己）

> **这份考卷官方 H+M = 0，所以"命中率"测不出来；在唯一可算的 Low 口径上我们是 0/2（漏 L-01、漏 L-02），假阳性 10/10。**
> **最值得记的不是分数，而是两条漏因都"不需要领域知识、也不需要链上数据"，纯粹是判据缺失（缺"批量操作单条失败是否应整批回滚"、缺"跨函数状态生命周期耦合"）⇒ 这是两个可以直接进 checklist 的补丁点。**
