# BLIND CANDIDATE LIST — C4 2025-07-lido-finance (CSM v2)

**生成时间:** 2026-09-27T23:40Z–00:20Z+08 (T+0 ~ T+43min)
**纪律声明:** 本清单在**读取官方 findings 仓之前**写完。此后才允许拉 `2025-07-lido-finance-findings`。
**读法:** 全量盲读 34 个 in-scope 文件（6967 SLOC, sloc.sh 口径），未使用 4naly3er-report.md，
未使用 test/ 目录，未使用 docs/ 目录。

严重度自评口径: H = 直接资损/永久锁死; M = 有条件资损或可复现 DoS/权限越界; L = 低影响/信息性。

---

## B-01 未加权限的 `finalizeUpgradeV2()` 再初始化函数 —— 可抢先占据 reinitializer 槽位
- **位置:** `src/CSModule.sol:158` · `src/CSAccounting.sol:106` · `src/CSFeeDistributor.sol:106`
- **机制:** 三者都是 `external reinitializer(2)`，**没有任何 `onlyRole`**。
  `Initializable.reinitializer(2)` 在 `_initialized < 2` 时把 `_initialized` 置为 2 并执行。
  若代理部署后、DAO 调用 `initialize()` 之前存在窗口，任意人可以调用 `finalizeUpgradeV2()`：
  ① 若它自身不 revert（CSModule 版本在全新代理上会走 `sstore(...,0)` 且不 revert）→ `_initialized = 2`，
  之后 `initialize()`（同为 `reinitializer(2)`）**永远 revert** ⇒ 合约永久不可初始化（DoS / 砖化）。
  ② `CSFeeDistributor.finalizeUpgradeV2(address)` 还会**写入 `rebateRecipient`**（无角色校验）⇒ 抢先者可把 rebate 接收地址设成自己。
- **我们给的严重度:** ②为 H（资金流向被改），①为 M（砖化）。
- **可达性:** 需要「代理部署」与「initialize」不在同一笔交易。`VettedGateFactory.create` 是原子部署+初始化（安全），
  但 `CSModule/CSAccounting/CSFeeDistributor/CSFeeOracle` 是 DAO 投票升级的代理，**仓库内无 script/ 可证明原子性**（本靶未含 script/）。中置信。
- **反证/自评:** Lido 部署实践通常是 `OssifiableProxy(data_=initialize calldata)` 原子化；若如此则该条不成立。⇒ 视为「待核」候选。

## B-02 未加权限的 `CSFeeOracle.finalizeUpgradeV2(uint256 consensusVersion)`
- **位置:** `src/CSFeeOracle.sol:80`
- **机制:** 无 `onlyRole`、无 `reinitializer`。内部 `_setConsensusVersion(v)` 仅在 `v == 当前值` 时 revert；
  `_updateContractVersion(2)` 要求当前版本为 1（v1→v2 升级窗口内成立）。
  任意人可在升级窗口调用，把 oracle 期望的 consensusVersion 设成任意值：
  抢先设成 DAO 将要设的目标值 ⇒ DAO 那笔 revert（`VersionCannotBeSame`）⇒ **升级流程被迫重走投票**。
- **严重度:** M（治理流程 DoS / 抢跑），非资损。
- **可达性:** 需要在 v1→v2 升级窗口内、DAO 调用之前。中低置信。

## B-03 `_claimWstETH` 单位不一致：用 wstETH 数额与 stETH **shares** 直接比较
- **位置:** `src/abstract/CSBondCore.sol:183-192`（`_claimWstETH`），对外为 `CSAccounting.claimRewardsWstETH`（`src/CSAccounting.sol`）
- **机制:** `claimableShares = _getClaimableBondShares()` 是 **stETH shares**；
  `sharesToClaim = requestedAmountToClaim < claimableShares ? requestedAmountToClaim : claimableShares`。
  但 `requestedAmountToClaim` 语义是 **wstETH 数额**（接口 `ICSAccounting.claimRewardsWstETH(wstETHAmount)`）。
  shares ≈ 1.15 × ETH，wstETH ≈ 1 ETH ⇒ 用户请求 X wstETH 时实际按 X **shares** 扣减与 wrap，
  即收到 ≈ 1.15X stETH 等值的 wstETH（上限为 claimableShares）。
  同一合约的 `_claimStETH`(162) 用了 `_ethByShares(claimableShares)` 做上界，`_claimUnstETH`(137) 同样 → **两个分支口径不一致本身就是信号**。
- **严重度:** M（记账/数额错误，用户可得超请求额，或超额请求被静默夹到 shares 口径）。
- **可达性:** 无权限，NO owner 自调；只需要有一个可领取余额>0 的 NO。高可达。
- **反证/自评:** 此写法在 CSM v1 已存在（属"遗留"），官方可能以"已知/非本次引入"驳回。低-中置信。

## B-04 `migrateToPriorityQueue` 无调用者授权 + 一次性权利可被他人消耗
- **位置:** `src/CSModule.sol:587`
- **机制:** 函数无权限校验，任意地址可对**任意** nodeOperatorId 调用。它把 `min(enqueuedCount, maxDeposits - totalDepositedKeys)` 个 key
  搬进 priority queue 并**永久置 `no.usedPriorityQueue = true`**（一次性权利被用掉）。
  攻击者可在 `maxDeposits - totalDepositedKeys` 很小（甚至 1）时抢先调用，
  消耗掉该 NO 唯一一次迁移机会，其剩余 enqueued key 永远留在 legacy queue（低优先级）。
- **严重度:** M（可用性/机会损失，非直接资损）—— 也可能是 L（因为迁移只影响排队优先级）。
- **可达性:** 任意地址，目标是「有 legacy enqueued key + 曲线 priority < QUEUE_LOWEST_PRIORITY」的 NO。高可达。
- **反证/自评:** 代码注释只承认"座位翻倍"的**好处**，未讨论第三方调用；官方可能认为无权限是故意设计（让 keeper 代劳）。中置信。

## B-05 `CSExitPenalties` 不校验 publicKey 属于该 nodeOperator
- **位置:** `src/CSExitPenalties.sol:60 (processExitDelayReport)` · `:93 (processTriggeredExit)` · `:131 (processStrikesReport)`
- **机制:** 三个入口都只做 `onlyModule` / `onlyStrikes`，然后用 `(nodeOperatorId, publicKey)` 作 key 写入罚金，
  但**从不验证该 pubkey 确实是该 NO 已存的签名 key**（`MODULE.getSigningKeys` 一类）。
  ⇒ 任何能让 `CSModule.reportValidatorExitDelay` / `onValidatorExitTriggered` 被调用的路径
 （`STAKING_ROUTER_ROLE`）都能给任意 NO 挂任意 key 的延期罚金；而 `CSModule.submitWithdrawals`
 对真正被提取的 key 读 `getExitPenaltyInfo(noId, pubkey)`，二者若 key 不匹配则罚金对不上（罚金挂空 / 或错挂）。
- **严重度:** M（罚金记账错误 / 由可信方误用放大为 M）。
- **可达性:** 需要 STAKING_ROUTER_ROLE（受信角色）⇒ 单独不可被外部攻击者触发，归属"防御性校验缺失"。
- **反证/自评:** C4 常把"仅受信角色可触发"的缺少校验判为 L/QA。低-中置信。

## B-06 `CSFeeDistributor._distributionDataHistory` 在空报告时记录**上一次**的 treeRoot/treeCid
- **位置:** `src/CSFeeDistributor.sol:176-186`
- **机制:** `processOracleReport` 中 `treeRoot/treeCid` 只在 `distributed > 0` 时更新，
  但历史记录结构体每次都写入当前的 `treeRoot, treeCid`。
  当 `distributed == 0`（合法的空报告）时，历史条目把上一轮的 root/cid 与本轮的 logCid/distributed 混在一起
  ⇒ 链上历史数据自相矛盾（对账/取证不可信）。
- **严重度:** L（数据可用性/可观测性，非资损）。
- **可达性:** oracle 正常行为；只影响链上历史语义。中高置信（确定是事实），但严重度低。

## B-07 `CSModule.obtainDepositData` 在 `unchecked` 中做 `enqueuedCount` 减法
- **位置:** `src/CSModule.sol:914`
- **机制:** `no.enqueuedCount -= uint32(keysInBatch)` 位于 `unchecked { … }` 块内（整段 for 体）。
  注释自认依赖不变量 `enqueuedCount >= keysInBatch`。若该不变量被破坏（例如
  `migrateToPriorityQueue` 与 legacy batch 并存、或 `cleanDepositQueue` 的部分状态），
  下溢会**静默回绕**成极大值 ⇒ 该 NO 永久 `depositable <= enqueued` ⇒ 再也不入队（该 NO 的存款永久停滞）。
- **严重度:** 若能构造则不变量破坏 ⇒ H；目前**未能构造**，仅记录为不变量风险。
- **可达性:** 未证明。**低置信，列为"待核"。**

## B-08 `CSAccounting.pullFeeRewards` 不受 `whenResumed` 约束
- **位置:** `src/CSAccounting.sol:352` 区域（`pullFeeRewards` / `_pullFeeRewards`）
- **机制:** 其它 `claimRewards*`、`deposit*` 均有 `whenResumed`；`pullFeeRewards` 是 external 且无暂停门，
  在会计合约暂停（如事故中）期间仍可把 fee 拉入 NO 债券。
- **严重度:** L（暂停语义不一致）。
- **可达性:** 任意人可对任意存在的 NO 调用。高可达。

## B-09 `VettedGate` 推荐计数与资格错配
- **位置:** `src/VettedGate.sol:380-393 (_bumpReferralCount)` · `:258-290 (claimReferrerBondCurve)`
- **机制:** `_bumpReferralCount` 只要「赛季开启 + referrer != 0 + referrer != msg.sender」就 `+1`，
  **不校验 referrer 是白名单成员、也不校验被推荐者是否真是新 NO 之外的独立主体**。
  真正取用时 `claimReferrerBondCurve` 只要求 **调用者**在 merkle tree 且有足够 referralCount。
  ⇒ 计数与资格两条链没有共同校验点；一旦白名单成员数为阈值提供了冗余，
  非白名单地址可先"刷计数"（虽不能自己领），语义上把"被推荐人数"与"有效推荐"解耦。
- **严重度:** L（经济设计缺陷，非直接资损）。
- **可达性:** 需要多个白名单成员各调一次。低置信（可能完全符合设计意图）。

## B-10 `CSStrikes.processBadPerformanceProof` 空 proof 允许 + 罚金/Eject 顺序
- **位置:** `src/CSStrikes.sol:127`
- **机制:** 允许空 `proof`（注释自证"无法用内部节点伪造"）；对每个条目先 `ejector.ejectBadPerformer`（触发全额提取）
  再 `processStrikesReport` 记罚金。`strikes` 只按该条自身 `data` 求和，**不跨条目累加**（因此"重复同一 key 累积 strikes"不可行，已排除）。
  唯一可疑点是：eject 成功但 `processStrikesReport` 因 `isValue` 已置而早退 ⇒ 罚金与提取不同步（幂等，非资损）。
- **严重度:** L / 非问题。
- **可达性:** —。**记为已排查（negative result）。**

---

## 已排查并**主动排除**（negative results，避免之后重复读）
- **N-1** `QueueLib.clean` 的 `enqueuedCount -= item.keys()` 是**检查过**的减法（非 unchecked），不变量破坏会 revert。
- **N-2** `CSModule.getNodeOperatorSummary` 里 `totalAddedKeys - totalWithdrawnKeys - totalUnbondedKeys` 位于 `unchecked`，
  但 `getUnbondedKeysCountToEject ≤ nonWithdrawnKeys` ⇒ 不可能下溢。
- **N-3** `CSModule.removeKeys` 只允许删 `startIndex >= totalDepositedKeys` 的 key；`removeKeysSigs` 把最后一个 key 搬进空位，
  搬移的 key 索引恒 ≥ `totalDepositedKeys` ⇒ 已提取 key 的 `_isValidatorWithdrawn` 指针不会被错位覆盖。
- **N-4** `CSModule.submitWithdrawals` 对同一 key 重复提交被 `_isValidatorWithdrawn[pointer] → continue` 拦住。
- **N-5** `CSModule._getQueue` 循环 `priority = 0..QUEUE_LOWEST_PRIORITY` **会**覆盖到 `QUEUE_LEGACY_PRIORITY = LOWEST-1`（不遗漏 legacy queue）。
- **N-6** `VettedGate.addNodeOperator*` 的 `_consume(proof)` 逐地址一次性；与 `PermissionlessGate`（不 consume）之间无 referral 交叉计数。
- **N-7** `CSAccounting.finalizeUpgradeV2` 在全新代理上会因 `bondCurvesInputs[0]` 越界 revert ⇒ B-01① 对它不成立（但它会 revert，不算砖化）。

## 我们"会提交"的清单（提交形态：file:line + 机制 + 严重度）
1. B-01② CSFeeDistributor rebateRecipient 抢占 — **H**（条件性）
2. B-03 `_claimWstETH` 单位错配 — **M**
3. B-04 `migrateToPriorityQueue` 无授权 — **M**
4. B-05 exit penalties 缺 pubkey 校验 — **M/L**
5. B-01① / B-02 finalize 抢先 — **M**
6. B-06 历史记录混写 — **L**
7. B-08 pause 语义不一致 — **L**
8. B-09 referral 设计 — **L**
（B-07 待核，不进提交）
