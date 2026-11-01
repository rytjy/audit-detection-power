# CANDIDATES - blind read 2025-11-merkl (isolated)

> 盲读产出。**未**参考任何 findings 仓 / official report / audits 目录。只读 scope 内两个合约 + 两个 interface。
> 时间盒 60 分钟 · 2026-11-01 · 阅读总量 1,259 行代码（DC 668 / D 558 / 接口 33）+ 70 行 scope 文件

## 汇总

| 档位 | 条数 |
|---|---|
| H | 0 |
| M | 3（D-1 / D-2 / DC-1） |
| L | 9 |
| 合计 | 12 |

**先说结论**：两个合约的资金主路径（Merkle 校验 / 累计领取 / 非重入 / 授权回落）是扎实的，**我没找到无权限的 H 级盗币路径**。
可提交的东西集中在三处：① 争议期机制的时间设计 ② 特权函数与用户资金混池 ③ 结算/回调语义不一致。
D-1 / D-2 / DC-1 我认为最值得交；其余多为 L / QA。

---

### D-1 | M | contracts/Distributor.sol:512-517（配 :305-320 updateTree、:288-296 disputeTree）| 争议窗口按整点向上取整，disputePeriod 默认 0 ⇒ 争议期可短至几十秒

- **机制一句话**：`_endOfDisputePeriod(T) = ((T-1)/epoch + 1 + disputePeriod) * epoch`，先把更新时间**向上取整到下一个 epoch 整点**，再加 `disputePeriod` 个 epoch。
- **影响 / 可利用路径**：`initialize()` **没有**设置 `disputePeriod`（默认 0；全文只有 `setDisputePeriod`(:391) 能改）。因此一次 `updateTree` 的争议窗口 = 距离下一个整点还剩多久：
  - 在 :59:30 更新根 ⇒ 窗口只有 **30 秒**；
  - 在整点后 :00:01 更新 ⇒ 窗口接近 1 小时。
  发布方的 updater 可以主动挑整点前几秒发根，把被人 `disputeTree` 的窗口压到几十秒（dispute 需要有人盯链 + 付保证金）；而 `disputeTree` 在窗口外**直接 revert**（:290 `block.timestamp >= endOfDisputePeriod` ⇒ InvalidDispute），**没有事后补争议的通道**。窗口一过 `getMerkleRoot()` 立即切到新根（:230-234），恶意根成为既成事实，只能靠 governor `revokeTree` 事后补救（而 `revokeTree` 又会被 active dispute 挡住）。
- **触发条件**：`disputePeriod == 0`（部署默认值）+ 发布方在 epoch 边界前几秒提交。
- **是否提交**：**是**。纯链上可验证的逻辑，不依赖外部假设，建议按 M 报，措辞写「争议期可被压缩至接近 0 秒」。
  - 反证（必须写进报告）：如果部署脚本每次都 `setDisputePeriod(>=1)`，窗口就变成「1 个 epoch + 零头」，最短仍有 1 小时 ⇒ 本条降级为 QA。部署脚本在禁读范围内，读不到，所以这条**自带前提**，提交时要显式写明。

### D-2 | M | contracts/Distributor.sol:352-364 resolveDispute | 押金判给做裁决的 governor 本人；且缺 nonReentrant

- **机制一句话**：`resolveDispute(false)` 把 disputer 的押金 `safeTransfer(msg.sender, disputeAmount)` —— 收款人就是**下裁决的那一方**；且先转账（:355/:359）后清 `disputer`（:362），函数没有 `nonReentrant`。
- **影响 / 可利用路径**：
  1. **利益冲突（设计层）**：争议的标的是「发布方/governor 发的树是否有效」。判无效 ⇒ 裁决者直接拿走押金；判有效 ⇒ 押金退回起诉人 + 树被回滚。即**裁决者对自己的判决结果有直接金钱激励**，押金还流向 governor EOA 而非国库，且无任何用途记录。这会把「有效争议」的判定率系统性压低，监督机制形同虚设。
  2. **重入（实现层）**：`resolveDispute` / `disputeTree` / `revokeTree` / `recoverERC20` 都没有 `nonReentrant`（只有 `_claim` 有）。若 `disputeToken` 是带转账回调的 token（ERC777 类；`setDisputeToken` 由 governor 任意指定），disputer 合约可在 :355 的 `safeTransfer` 回调里重入 `resolveDispute(true)`：此刻 `disputer` 仍非 0（:353 的 NoDispute 不触发）⇒ **再付一次 disputeAmount 给 disputer，并再执行一次 `_revokeTree`**。若该 token 在合约里还留有其它余额（例如它同时是某活动的奖励 token），可被多提走。
- **触发条件**：① 恒定存在；② disputeToken 具备转账钩子 + disputer 是合约 + 合约内该 token 余额 > disputeAmount。
- **是否提交**：**是，拆两条交**。① 按 M「争议裁决者与押金受益人同一人」；② 按 M/L「resolveDispute 缺重入保护」，若程序认定 disputeToken 只可能是标准 ERC20 则降 L。

### DC-1 | M | contracts/DistributionCreator.sol:423-431 recoverFees（配 :284-286、:299-302）| 手续费回收会扫走用户预存余额

- **机制一句话**：用户的预存余额 `creatorBalance` 是**真实转进 `address(this)` 的 token**（:285 `safeTransferFrom(msg.sender, address(this), amount)`），而 `recoverFees` 发的是 `tokens[i].balanceOf(address(this))` —— **整仓余额**；合约里不存在「手续费池 / 用户余额池」的分离记账。
- **影响 / 可利用路径**：
  ```
  creator A 预存 100 USDC          => 合约余额 100, creatorBalance[A] = 100
  B 建活动，费 10 USDC             => feeRecipient 未设 => 费留合约(:590)，余额 110
  governor 调 recoverFees([USDC],gov) => 转走 110（含 A 的 100）
  => A 之后 decreaseTokenBalance 全部 revert（账上还有 100，币没了）
  ```
  即一个被文档描述为「提取协议手续费」的函数，实际能一次性掏空**所有**活动创建者的预存款；受害者余额数字还在账上，但取不出来。同类问题在 `Distributor.recoverERC20`（:379-383，governor 可转任意数量，把未领取奖励扫走，且没有「意外转入」的界定）。
- **触发条件**：任意时刻存在 `creatorBalance > 0` + 一次 governor 调用（恶意 governor / 私钥泄露 / 运维脚本误操作均可）。
- **是否提交**：**是**，按「特权函数与用户资金混池，缺隔离记账」报。若程序明确 admin 完全可信 ⇒ 降 L；但**函数语义与实际行为不符**这一点不依赖信任假设，值得坚持。

### D-3 | L | contracts/Distributor.sol:288-296 + :305-312 + :369-372 | 一笔押金即可冻结全部树更新，且无第三方自救路径

- **机制一句话**：`updateTree` 第一条就判 `disputer != address(0)` ⇒ revert；`revokeTree` 同样 `if (disputer != address(0)) revert`。争议期间**只有 governor 的 `resolveDispute` 能解锁**。
- **影响 / 可利用路径**：任何人付 `disputeAmount` 就能让 `disputer` 非 0 ⇒ 受信 updater 全部停摆、governor 也不能 `revokeTree`。停摆时长 = 治理响应时间。若 `disputeAmount` 被设为 0（`setDisputeAmount`(:414-417) 无下界校验）或使用廉价 token ⇒ **零成本无限期 DoS**；即便有押金，判 invalid 时押金进 governor 口袋而非国库，攻击成本可能低于停摆收益（竞争协议 / 做空）。叠加 D-1：挑整点前发根 + 立刻 dispute 可以让树在「旧根」上长期冻结。
- **触发条件**：`disputeAmount` 为 0 或很小；攻击者愿付成本。
- **是否提交**：**是（L）**，可与 D-1 合并成一条「争议机制的时间与经济性」。

### D-4 | L | contracts/Distributor.sol:479-486 | onClaim 空 catch 全吞 + 回调金额语义与实际转账不一致

- **机制一句话**：`try IClaimRecipient(recipient).onClaim(user, token, amount, data) ... catch {}` —— ① 收款合约的任何失败（含 gas 耗尽）被静默吞掉，claim 仍算成功；② 传给回调的是**累计值 `amount`**，实际转入的只有**增量 `toSend`**（:465/:480）。
- **影响 / 可利用路径**：
  - ① **状态分裂**：收款合约（自动复投/质押类）的记账没跑，但 `claimed` 已被推到累计值 ⇒ 用户再也拿不到这段增量（`toSend` 变 0 后回调根本不再触发，:479），无重试入口、无事件可追。资金没丢，但「应得的二次收益」永久丢失。
  - ② **超额记账**：recipient 若按 `amount` 铸份额/记债权，第二次领取时按累计值而非增量记账 ⇒ 下游多记 `claimed` 那么多。属接口语义模糊导致下游可被薅，取决于 recipient 实现（禁读）。
  - ③ `revert Errors.InvalidReturnMessage()` 写在 try 的 success 分支里（:483），**不会被自己的 catch 捕获**（Solidity 语义）⇒「返回错值 = 整批 revert」而「调用 revert = 静默通过」，同一错误面两种相反处理。
  - ④ `datas` 由 caller 任意给出，即使 operator/mainOperator 替用户领取，也会把**攻击者可控的 data** 打进**用户的**收款合约（:482）。若 recipient 的 `onClaim` 对 `data` 有权限含义，即被放大成越权面。
- **触发条件**：收款人是合约（`setClaimRecipient` 指向合约）；operator/mainOperator 发起领取。
- **是否提交**：**边缘（L）**。①③ 是确定的实现问题；②④ 需 recipient 实现才能定级，建议按「接口契约不明确 + 静默失败」交，不要硬吹成 H。

### DC-2 | L | contracts/DistributionCreator.sol:594-602 | 授权额度不足时静默改从调用者钱包扣款，且额度不消耗

- **机制一句话**：`userBalance >= campaignAmount` 且 `msg.sender != creator` 时，若 `creatorAllowance < campaignAmount` **不 revert**，而是走 else 从 `msg.sender` 自己钱包全额 `safeTransferFrom` 后 `return`（额度不减、creator 余额不动）。
- **影响 / 可利用路径**：operator 以为在花管理员的预存余额，实际扣自己钱包且无回滚无提示；反向语义也成立 —— 授权本意是「最多花我多少」，实现变成「额度够就花我的、不够就花你的」，**额度上限被绕过**。对 creator 的后果是活动资金来源与预期不符；对 operator 是可被反复「诱导付款」（每次自损，但配合 rebate/会计脚本会产出错账）。
- **触发条件**：creator 有预存余额 + 给了偏小的额度 + 活动金额 > 额度。
- **是否提交**：**边缘（L）**。无第三方获利路径；若要交，措辞必须是「额度不足应 revert 而非静默换资金来源」。

### DC-3 | L | contracts/DistributionCreator.sol:236-258 overrideCampaign | 结束时间校验用旧 startTimestamp，起始时间可改成任意值

- **机制一句话**：允许活动开始前改 `startTimestamp`（:242），但「结束时间必须在未来」的校验写死用**原始** `_campaign.startTimestamp`（:244），没有用 `newCampaign.startTimestamp`。
- **影响 / 可利用路径**：活动开始前可把 `startTimestamp` 改成 0（远古）或远未来，配一个只对旧起点合法的 `duration` ⇒ 链上出现「结束时间在过去 / 开始时间在 100 年后」的活动。同时 `campaignType` / `campaignData` / `duration` 全可改、**不校验活动是否已结束**、不限次数（`campaignOverridesTimestamp` 无限 push，:257 ⇒ view gas 无限增长）。
- **触发条件**：活动未开始 + creator/operator 恶意或参数误用。
- **是否提交**：**边缘（L）**。代码自己写了「Merkl engine validates override correctness; invalid overrides are ignored」（:230-233）⇒ 链上无效 override 由链下兜底，**H 不成立**；价值在于「链上应拒绝而非依赖链下白名单」+ 数组无限增长。

### DC-4 | L | contracts/DistributionCreator.sol:261-279 reallocateCampaignRewards | 无去重、无 to != 0、目标可反复覆盖

- **机制一句话**：把「活动结束后未领取的奖励」从 `froms` 重定向到 `to`；只 push 不校验，`to` 可为 `address(0)`，同一活动可反复调用、`froms` 可重复、`campaignListReallocation` 无限增长。
- **影响 / 可利用路径**：
  - `to == address(0)`：链上不拒绝；若引擎接受该重定向 ⇒ 奖励指向零地址，永久无法领取（burn）。引擎是否过滤不可见（禁读）。
  - **目标可变**：先公布 `to = 官方多签`，活动结束后再改成攻击者地址 —— 链上无「一旦设定不可更改」约束，第三方只能靠链下快照判断，属「可变更的承诺」。
  - `froms` 重复 ⇒ `campaignListReallocation` 重复计数，链下按数组（而非 mapping）汇总的脚本会重复支付。
- **触发条件**：活动结束 + creator/operator 调用（可反复）。
- **是否提交**：**边缘（L）**。定级依赖链下引擎如何消费 `campaignReallocation`，读不到。

### DC-5 | L | contracts/DistributionCreator.sol:641-649 | getValidRewardTokens(skip, 0) 必 revert（内存数组越界）

- **机制一句话**：`returnSize = min(first, rewardTokens.length)`；`first == 0` 时 `new RewardTokenAmounts[](0)`，但循环仍会在 `minAmount > 0` 时执行 `validRewardTokens[0] = ...` ⇒ 越界，Solidity 0.8 抛 Panic(0x32)。
- **影响 / 可利用路径**：纯 view，前端/API 分页写 `first=0` 直接报错而不是返回空数组。无资金损失，但确定性、易复现。
- **触发条件**：`getValidRewardTokens(skip, 0)`。
- **是否提交**：**边缘（QA/L）**，作为 QA 交，不占正式名额。

### DC-6 | L | contracts/DistributionCreator.sol:479-482 + :620-634 | feeRebate 无上限 ⇒ 单地址建活动永久 DoS

- **机制一句话**：`setUserFeeRebate` 不校验 `userFeeRebate <= BASE_9`；`_computeFees` 里 `BASE_9 - feeRebate[msg.sender]` 在 rebate > 1e9 时下溢 revert。
- **影响 / 可利用路径**：governor/guardian 一次误配（或恶意）即让该地址**永久无法创建任何活动**，用户自己无法自愈（改不了 rebate）。另：rebate 按 `msg.sender` 计而费用从 `creator` 扣（:625 注释自认），operator 用满额 rebate 替 creator 建活动时 creator 免不了费 —— 这是文档化的设计选择，不算漏洞。
- **触发条件**：`feeRebate[x] > 1e9`。
- **是否提交**：**否**（参数校验缺失 + 特权误配，QA 级，单独交价值低）。

### DC-7 | L | contracts/DistributionCreator.sol:527-544 | _createCampaign 不校验 creator 授权，任何人可以任意地址名义建活动

- **机制一句话**：`newCampaign.creator` 直接取自入参（:536 仅在为 0 时落回 msg.sender），`_createCampaign` 里**没有** `_isValidOperator(creator)`（该检查只出现在 `overrideCampaign` / `reallocateCampaignRewards`）。
- **影响 / 可利用路径**：① **campaignId 抢占** —— ID 含 creator（:396-411），攻击者用与受害者真实活动完全相同的参数先建一次，受害者的 `createCampaign` 就 `CampaignAlreadyExists` revert（:539），代价是攻击者要真实付全额奖励；② **归属混淆** —— 链下按 creator 聚合的看板/空投会把攻击者的活动算到受害者头上；③ 受害者（或受害者的 operator）随后可对**不是自己出的钱**调用 `overrideCampaign` / `reallocateCampaignRewards`，把未领取奖励改到自己名下。
- **触发条件**：无权限门槛；成本 = 活动金额 + 手续费。
- **是否提交**：**边缘（L）**。无直接盗币，① 成本高，②③ 偏社会工程。

### D-5 | L | contracts/Distributor.sol:452 | 用 tx.origin 做领取授权

- **机制一句话**：`tx.origin != user` 是授权条件之一 ⇒ **用户调用的任何合约都能替用户领取**。
- **影响 / 可利用路径**：收款地址被强制回落到用户自己/用户设定（:472-477），无直接盗币；但任何用户交互过的合约都能在任意时刻替用户触发领取（把 `claimed` 推到当前根累计值、把币打给用户）。危害：① 钓鱼合约可提前「消耗」用户下一次真实领取，制造「没到账」的错觉；② 与 D-4④ 叠加时，用户设定的收款合约会被第三方以**任意 data** 触发。
- **触发条件**：用户向任意合约发起交易。
- **是否提交**：**否**（无直接损失，作 QA/smell 提；与 D-4④ 组合可升 L）。

---

## 显式否定（读过并主动排除）

1. **Merkle 双花 / 重放** —— 排除。`claimed[user][token]` 是**累计值**且单调递增，`toSend = amount - claimed`（:465）下溢即 revert；重复提交同一 `(user,token,amount)` 第二次 `toSend = 0`，不转账；状态在转账前写入（:466 早于 :480），checks-effects-interactions 成立；外加自实现 `nonReentrant`（:169-181）覆盖整个 `_claim`。同批内重复 `(user,token)` 也只按累计净额结算。
2. **Merkle 叶子/内部节点混淆（second-preimage）** —— 排除。叶子是 `keccak256(abi.encode(address,address,uint256))`（:461），内部节点是两段 32 字节 `abi.encode` 拼接（:521-527）；要伪造需构造 `(address,address,uint256)` 使其哈希等于某个内部节点 ⇒ 需要 preimage，不可行。叶子未用 `abi.encodePacked`，无拼接歧义。
3. **campaignId 哈希碰撞** —— 排除。`abi.encodePacked(CHAIN_ID, creator, rewardToken, campaignType, startTimestamp, duration, campaignData)`（:396-411）中唯一的动态项 `campaignData` 在末尾，前面全定长 ⇒ 无 pack 歧义。另确认 `amount` 不参与 ID：两次只差金额的建活动会撞 ID 并 revert（:539），这是**特性**不是漏洞，且费用先扣后被整体回滚，无资金损失。
4. **_campaignLookup 差一错误** —— 排除。写入 `length + 1`（:540），读取 `index - 1`（:369-373），首个活动存 1 读 0；0 保留为「不存在」，`campaign()` 对不存在 ID revert。
5. **_getValidRewardTokens 的 mstore(arr, length) 缩短数组** —— 排除（除 DC-5 的 `first==0` 特例）。`length` 只增不减且上限为 `returnSize`，assembly 只做**缩短**，不会暴露未初始化内存。
6. **_pullTokens 的读写顺序 / 重入** —— 排除。余额路径里 `_updateBalance` 在任何转账**之前**写（:604 早于 :605-606），额度也在转账前递减（:597）；不存在「外部调用后用过期的 userBalance 覆盖写」。（唯一的怪异是 :598-602 的静默改扣款，已列 DC-2。）
7. **`1 - x` 型开关下溢** —— 排除。`toggleCampaignOperator`(:311)、`toggleSigningWhitelist`(:489)、`toggleOperator`(:246)、`toggleMainOperatorStatus`(:266)、`toggleTrusted`(:329) 的映射值只会被写成 0/1，无第三方写入 2 的路径，`1 - x` 不会下溢。
8. **updateTree 的布尔优先级错误** —— 排除。`disputer != 0 || ((!trusted || now < end) && !governor)`（:305-312）语义正确：有争议全挡、争议期内挡非 governor、争议期外放行 trusted。未发现「trusted 绕过争议期」的写法。
9. **initialize 重入 / 零地址** —— 排除。两合约都是 `constructor() initializer {}` + `initialize` 的 OZ `initializer`；DC 校验零地址与 `_fees < BASE_9`（:180-187），Distributor 校验 `_accessControlManager != 0`。
10. **_claim 的 recipient 覆盖导致盗币** —— 排除。`if (msg.sender != user || recipient == 0)`（:472）保证**非本人调用时一律回落到用户设定的 recipient 或用户本人**，operator / mainOperator / tx.origin 三条路径都改不了收款地址。
11. **代币扣款不足 / 超额铸造** —— 排除。`_computeFees` 两处除法都向下取整 ⇒ 费用向上取整（利于协议），用户无法少付费；`decreaseTokenBalance` / `decreaseTokenAllowance` 用 `-` 且无 unchecked，下溢即 revert。
12. **批量操作部分失败** —— 排除。`createCampaigns`(:200-212) 与 `_claim` 都在单 tx 内循环，任一失败整体回滚，不存在部分成功的中间态。
13. **_claim 的 uint208 / uint48 截断** —— 排除。`SafeCast.toUint208(amount)` 越界即 revert；`uint48(block.timestamp)` 到公元 8.9M 年才截断。
14. **hasSigned 的 tx.origin 导致代付** —— 排除（对盗币而言）。钓鱼合约虽能以用户的 tx.origin 通过 `hasSigned`，但 `creator` 默认落回 msg.sender（:536）、扣款也从 msg.sender 走（:607-609），钓鱼方只能花自己的钱。仅属 tx.origin 用法 smell。

---

## 覆盖声明

**已读（全文逐行，非抽样）**

| 文件 | 行数 |
|---|---|
| contracts/DistributionCreator.sol | 668 |
| contracts/Distributor.sol | 558 |
| contracts/interfaces/IAccessControlManager.sol | 21 |
| contracts/interfaces/IClaimRecipient.sol | 12 |
| scope.txt | 2 |
| out_of_scope.txt | 68 |
| **合计** | **1,329** |

被审计代码本体 = **1,259 行**（668 + 558 + 33）。接口只读了 scope 内两文件 import 的两个。

**未读 / 读不到（相关结论均带前提）**

- `contracts/struct/CampaignParameters.sol` / `DistributionParameters.sol` / `RewardTokenAmounts.sol`：字段类型与顺序未知 —— 影响 `overrideCampaign` 的逐字段推理、`NewCampaign` 事件语义、结构体打包。**按任务硬约束不读。**
- `contracts/utils/Errors.sol`：只见到 revert 名，无自定义错误定义。
- `contracts/utils/UUPSHelper.sol`：`onlyGovernorUpgrader` 的实际实现未知，**升级权限边界未验证**（未据此下任何结论）。
- `contracts/AccessControlManager.sol`（out of scope）：`isGovernor` / `isGovernorOrGuardian` 的真实语义（guardian 是否继承 governor）未验证。
- 部署/初始化脚本（`scripts/DistributionCreator.s.sol` 等）：未读 ⇒ D-1 的 `disputePeriod` 实际部署值、D-2 的 `disputeToken` 实际币种、D-3 的 `disputeAmount` 实际值均为**未验证前提**，已在条目内显式写出。
- 测试、mock、partners、Disputer、ReferralRegistry、DistributionCreatorWithDistributions：全部未读（out of scope / 禁读）。
- 未联网、未 spawn 子线程、未读任何 findings / official report / audits / docs / PREREG / FREEZE / 4naly3er 文件。

**方法论边界**：本清单只做静态推理，**未编译、未跑 PoC、未 fork**（时间盒内）。所有「是否提交」是基于**代码可读性**的初筛，不是可利用性的最终证明。D-1 / D-2 / DC-1 若提交，建议各补一个 ≤20 行的 Foundry PoC（尤其 D-1：本地把 `disputePeriod` 设为 0，在整点前 30 秒 `updateTree`，断言 `endOfDisputePeriod - block.timestamp < 60`）。

