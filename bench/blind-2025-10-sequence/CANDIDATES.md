# CANDIDATES — blind-2025-10-sequence

(骨架，增量追加)

## 候选（边读边追加）

### C-01 会话显式权限的"累计用量"写回依赖内存引用语义（待验证）
- 位置: src/extensions/sessions/explicit/PermissionValidator.sol:74-105
- 机制: `usageLimit = UsageLimit({usageHash, 0}); newUsageLimits[j] = usageLimit;` 之后才 `usageLimit.usageAmount = value256;`。若 `newUsageLimits[j] = usageLimit` 是"值拷贝"（Solidity 内存数组元素为内联布局时），数组元素里的 usageAmount 会停留 0；随后 `_validateLimitUsageIncrement` 用这个 0 构造期望的 incrementUsageLimit 数据，链上累计量被写成 0 ⇒ 累计上限可被无限绕过。若为"引用语义"则无此问题。
- 触发者/条件: 任何被显式会话授权的 session signer，且配置里有 cumulative 规则
- 影响类: 资金损失（超额花费绕过累计上限）
- 为什么不是设计意图: 注释与 `incrementUsageLimit` 的单调递增检查都表明累计量必须真实累加
- 置信度: 待定（取决于 Solidity 内存赋值语义，需实验确认）

> ⚠️ **C-01 撤回（2026-10-01，实测）**：用本机 solc 0.8.28 + forge 实测：`L[] memory arr = new L[](1); L memory l; arr[0] = l; l.a = 42;` 之后 `arr[0].a == 42`；反向 `l = arr[0]; l.a = 42` 后 `arr[0].a == 42`；未初始化元素读 0（脏 scratch 也不泄漏）。⇒ Solidity 内存数组元素为**引用**语义，`usageLimit.usageAmount = value256` 会写回数组元素。**PermissionValidator 的累计逻辑无此缺陷**，C-01 作废（见「已否定的方向」）。

### C-02 会话调用签名未绑定钱包地址，同一会话配置在多钱包/多链可重放
- 位置: src/extensions/sessions/SessionSig.sol:406-419（`hashCallWithReplayProtection`）；对照 src/modules/Payload.sol:27-37（EIP-712 domain 含 verifyingContract）
- 机制: 会话签名者对每个 call 签的是 `keccak256(chainId_or_0, space, nonce, callIdx, hashCall(call))`——**没有钱包地址**。而系统其余部分都锚钱包：EIP-712 domain 用 `verifyingContract`，`BaseAuth.recoverSapientSignature` 还把 `msg.sender` 追加进 `parentWallets` 参与哈希。于是：只要两个钱包的会话配置（签名者/权限/identity signer）相同，同一个 call 签名在另一个钱包上仍然 recover 出同一 sessionSigner、且 (space,nonce) 若未用过就通过 ⇒ 观察者可把为钱包 A 签的调用搬到钱包 B 执行。
- 触发者/条件: 持有会话签名密文的中继者/旁观者；需要目标钱包存在同一会话配置（同一 SDK/同一助记人的多钱包，或同一签名者被多钱包授权）；`noChainId` 置位时还可跨链
- 影响类: 未授权资金转移（对第二个钱包）/ 越权
- 为什么不是设计意图: 其它所有签名路径都显式把钱包地址绑进哈希，会话路径唯一漏掉，且 nonce 空间也不含钱包信息
- 置信度: 中

### C-03 隐式会话的 attestation 没有有效期，`issuedAt` 从不校验
- 位置: src/extensions/sessions/implicit/ImplicitSessionManager.sol:22-57；src/extensions/sessions/implicit/Attestation.sol:28-31,53-66,82
- 机制: attestation 里编了 `authData.issuedAt`（并被 identity signer 签名覆盖），但校验路径只做四件事：approvedSigner 匹配、非 delegateCall、sessionSigner/目标不在黑名单、目标合约返回 magic。`issuedAt` 从头到尾没被读取或比较，也没有 deadline/过期字段。⇒ 一条 identity signer 签发的隐式会话授权在被移出钱包配置（image hash 变更）之前**永久有效**，无法在链上按时间回收。
- 触发者/条件: 任何持有该 attestation（及会话签名）的被授权 session signer；撤销只能靠改配置或黑名单
- 影响类: 越权（过期授权仍可长期动用钱包资产）
- 为什么不是设计意图: 既然把 issuedAt/redirectUrl 编进被签名的 attestation，却不做任何时间校验，等于白编；文档也把它列为授权数据
- 置信度: 中

### C-04 `incrementUsageLimit` 是单例上**无任何访问控制**的状态写函数
- 位置: src/extensions/sessions/explicit/ExplicitSessionManager.sol:19-31；键位 src/extensions/sessions/explicit/PermissionValidator.sol:19,33-36
- 机制: `incrementUsageLimit(UsageLimit[] calldata limits)` 是 `external`，无 `onlySelf`、无调用者校验，`address wallet = msg.sender`。合约是**所有钱包共享的单例**（`_validateExplicitCall`/`_validateLimitUsageIncrement` 都用 `call.to == address(this)` = 该单例地址）。即任何地址都能对自己的 `limitUsage[自己][任意 usageHash]` 写入任意值（含把哈希凑到某个将会被会话使用的值）。设计上它只应由钱包在自调用执行时触发。
- 触发者/条件: 任意地址；实际影响面受 `msg.sender` 键限制（只能写自己的表项），且函数自身禁止"减量"
- 影响类: 状态不一致 / 权限边界（潜在的后续 DoS：一旦某地址成为钱包，其表项可被预先污染）
- 为什么不是设计意图: 这是一个共享单例上唯一无门禁的写状态外部函数；其它所有写函数都带 `onlySelf`/签名门禁
- 置信度: 低（无法据现有代码构造出跨账户影响；作为"应当加固的点"提出）

### C-05 保留值 `behaviorOnError == 3` 的失败调用被静默当作成功
- 位置: src/modules/Calls.sol:103-121；同一模式 src/Guest.sol:55-73
- 机制: 调用失败后只判 IGNORE(0)/REVERT(1)/ABORT(2)；编码允许 3（保留）。值 3 不匹配任何分支 ⇒ 不 revert、不 break，直接落到 `emit CallSucceeded(_opHash, i)` 并继续。⇒ 一笔失败的调用对外呈现为"成功"事件，且批量继续执行。会话路径只禁止 ABORT(2)，不禁止 3。
- 触发者/条件: 任何能构造 payload 的签名者（会话 signer 亦可，只要该 call 的权限校验通过——例如权限规则没覆盖到该字段时）
- 影响类: 状态不一致 / 计价错误（依赖事件对账的集成方会误判）
- 为什么不是设计意图: 文档把 11 定义为"Reserved"，未定义行为却走了成功分支
- 置信度: 中低

### C-06 `Hooks` fallback 对未知 selector 返回"成功且空返回"
- 位置: src/modules/Hooks.sol:106-119
- 机制: `if (msg.data.length >= 4) { target = _readHook(sel); if (target != 0) {delegatecall} }` —— 若没有注册 hook，函数直接结束，**外部调用拿到 success + 0 字节返回**。任何 probe 任意接口的调用都会"成功"（而不是 revert/返回 0x0）。
- 触发者/条件: 任何人
- 影响类: 状态不一致（接口探测/兼容性判断被误导；例如集成方按 success 判定"钱包接受该调用"）
- 为什么不是设计意图: 未实现的 selector 静默成功不是常规 fallback 语义
- 置信度: 中低

### C-07 `noChainId` 位（bit1）可由会话签名者自行置位 ⇒ 会话调用签名跨链可重放
- 位置: src/modules/auth/BaseSig.sol:113-114（`_payload.noChainId = signatureFlag & 0x02 == 0x02`）；使用点 src/extensions/sessions/SessionSig.sol:410-418
- 机制: 会话的 call 签名哈希把 chainId 换成 0，只要顶层签名 flag 的 bit1 置位（会话路径下整个签名外壳都由会话签名者构造）。系统对该位无任何约束 ⇒ 一条会话授权在链 A 被中继上链后，观察者可在链 B 重放（B 上钱包配置相同、space/nonce 未用）。
- 触发者/条件: 会话签名者选了 noChainId（或中继者…注：改位会破坏外层 recover，实际需签名者自己置位）；重放者只需观察交易
- 影响类: 越权 / 资金损失（跨链重复执行同一批调用）
- 为什么不是设计意图: 文档把 noChainId 定位为"配置更新可全链生效"的场景，会话（尤其含转账的批量调用）并不需要它
- 置信度: 中低

## 已否定的方向（读过但判断不是问题）

- **累计用量写回丢失（原 C-01）**：实测 solc 0.8.28 下内存数组元素为引用语义，`arr[i] = local; local.f = x;` 会写回数组（t1/t2/t3 全 PASS，且未初始化元素读 0、脏 scratch 不泄漏）⇒ `PermissionValidator.sol:83-102` 的 `usageLimit.usageAmount = value256` 有效；该方向排除。
- **FLAG_ADDRESS 叶子（BaseSig.sol:242-260）不加权重**：看似"声明地址即得权重"的漏洞，但代码注释与 SIGNATURE.md（"Just an address leaf (with no actual ECDSA check)"、"No weight added"）一致 ⇒ 是有意为之（且不加权重才是安全选择）。
- **`incrementUsageLimit` 只能单调递增**：`limits[i].usageAmount < getLimitUsage(...)` 即 revert，无法通过它"回退"用量（排除"用量回退绕过上限"）。
- **会话 permission index 未进签名**：可被改写，但 `_validateExplicitCall` 只用它在该 **同一 sessionSigner 自己**的 permissions 数组里选一项（permIdx 不跨签名者）⇒ 同一签名者本就可用任一自己的权限，改写无增益。
- **黑名单可为空（count=0）**：空黑名单不拦截任何地址，但"必须有黑名单节点"只要求节点存在；配置方自己给了空 deny-list，不算绕过。
- **黑名单计数双编码（nibble vs 0x0F+uint16）与未用 nibble 不进 leaf hash**：同一配置有两种字节编码得到相同 imageHash（可变形性），但解析结果与权限完全相同 ⇒ 无权限增益。
- **`Payload.fromPackedCalls` / `BaseSig.recoverBranch` 越界读**：LibBytes 文档明确"不检查边界、可能读到脏值"，越界数据全部来自调用者自己的 calldata，只能自伤。
- **`Nonce._consumeNonce` unchecked 溢出到 0**：需要把某 space 的 nonce 推进到 `type(uint256).max`（每笔只能 +1），不可达。
- **empty `_signature` 走非静态分支**：得到 weight/threshold 全 0，最终仍需 `_isValidImage(imageHash)` 成立，无法命中真实钱包配置。
- **`validateUserOp` 不校验 `userOp.sender == address(this)`**：`entrypoint` 是 immutable，只有受信 EntryPoint 能调用，且 EP 只会用 sender=账户 调回来。
- **`Factory.deploy` 无门禁**：CREATE2 地址同时绑定 mainModule（init code hash）⇒ 抢占部署也只能用正确模块、正确 salt，攻击者无法控制该钱包（无签名）。
- **`Hooks.fallback`/`Calls` delegatecall 任意目标**：delegateCall 只在 owner 级签名或 `selfExecute`(onlySelf) 下可达，会话路径显式禁止。
- **`Guest`**：sponsor README 明确列为非安全关键、只做模拟/临时会话，且其 `_dispatchGuest` 已禁 delegateCall；不列候选。
- **`Recovery` 队列条目永不清除**：重放同一恢复载荷受钱包 nonce（`execute` 会 `_consumeNonce`）约束；且根哈希必须命中钱包配置里的 recovery 叶子，攻击者无法自造签名者。
- **Passkeys 树形状 `k(k(x,y), k(ruv,metadata))`** 与文档示意图的折叠顺序是否一致：无法在无 SDK/测试的情况下判定，且属"验证口径"而非可构造攻击，未列候选。
- **`SessionManager` 要求 limit 场景下 call0 必须是 increment 调用**（文档已写明"a preceding call to incrementUsageLimit is required"）：是设计约束，仅限制批量顺序。

## 覆盖情况

- **文件覆盖：47/47 in-scope 文件全部读完（100%）**，另读了 `docs/*.md`（SESSIONS/PAYLOAD/SIGNATURE/CHAINED/CONFIGURATIONS）与 README-sponsor 作为意图基线；`scope.txt` 列的 47 行与 `find src` 一致。
- **SLOC**：`wc -l` 统计 `src/` 共 4850 行，其中 out-of-scope 的 `Estimator.sol`(111)+`Simulator.sol`(109)=220 行未读 ⇒ **in-scope 实读 ≈4630 行**（任务书写的 4297 应为去空行/去注释口径），核心 5 个 >120 行的文件（BaseSig 500、SessionSig 421、WebAuthn 333、Payload 278、Recovery 217）逐行读完。
- **未读/未读透**：
  - `src/Estimator.sol`、`src/Simulator.sol`（明确 out-of-scope，未读）
  - `script/`、`test/`（已从仓库剔除，无法用测试作为口径校验）
  - 未做动态验证：**没有为任何候选构造 PoC**（时间盒内只做了 1 个纯语言语义实验，见 C-01 撤回）。C-02/C-03/C-05/C-06/C-07 都是静态推理，其中 C-02 的"多钱包同配置"前提未在链上验证。
  - `WebAuthn.sol`/`P256.sol`/`Base64.sol` 属 Solady 移植代码，只做了常规审读（RIP-7212 回退、malleability、base64 前缀拼接），未逐位复核汇编。
