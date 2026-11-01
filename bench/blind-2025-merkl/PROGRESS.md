# Blind bench #5 — 2026-11-01 — PROGRESS

- START: 2026-11-01 10:0x +0800（月度盲测，自动任务）
- 靶（暂定，待分母/日期确认）：2025-11-merkl（Angle Merkl 奖励分发；slug 已确认 code-423n4/2025-11-merkl）— 前批预验 `H+M=3 (0H/3M)`，Solidity，未跑过（已用：lido 2025-07 / hybra 2025-10 / sequence 2025-10 / megapot 2025-11）
- 为何选它：域贴我们的族（记账 / 份额 / 领取 / 权限）> panoptic-next-core（22 但期权 AMM，域不贴）；分母 ≥3 满足规则
- 下一步：确认 report slug 与代码仓 → 消毒 → VPS 取码 + sha256 → PREREG 冻结 → isolated 子线程盲读
- 纪律：不下载任何 `-findings` 仓；不读 report 正文（只取 `aggregated total of N`）；先落盘候选 → 再对答案
- 10:0x slug 确认：`2025-11-merkl`（C4 org 仓名，非 -findings）
- 分母预验 10:0x：`aggregated total of 3 unique vulnerabilities.`（仅计数；**正文未读**，html 已删避免污染，冻结后重抓）
- 10:03 取码 codeload tar.gz 1,584,983 B sha256 53ecef61…469a42（本地直连被 reset，改走 127.0.0.1:3128 成功）
- 10:03 消毒：删 2025_11_merkl_v12.md / 4naly3er-report.md / discord-export/
- 10:03 PREREG.md 写死并冻结 sha256 151c5272…b2a819（mtime 10:03:49）
- 10:04 spawn isolated 子线程 runId cae46bbd-c8d8-4ab5-a061-6b3eee6f87b9（60min，无清单 OFF）
# PROGRESS - blind read 2025-11-merkl

- 10:05 起跑。读 scope.txt(2 行) / out_of_scope.txt(68 行) / README-sponsor.md -> 确认只有 2 个合约在 scope，其余（Disputer / ReferralRegistry / structs / utils / mocks / scripts）全部禁读。下一步：通读 DistributionCreator。
- 10:07 读完 DistributionCreator 1-400（存储布局、modifier、createCampaign/createCampaigns、overrideCampaign、reallocate、creatorBalance/creatorAllowance/campaignOperators）。初步想到：recoverFees 扫整仓余额 vs creatorBalance 预存混池；_pullTokens 额度不足时静默改扣 msg.sender。下一步：DC 400-668。
- 10:08 读完 DC 400-668（recoverFees/setFees/setRewardTokenMinAmounts/_createCampaign/_pullTokens/_computeFees/_getValidRewardTokens）。确认 feeRecipient 在 initialize 里从不设置(默认 0 => 费留本合约)；_getValidRewardTokens 在 first==0 时会越界写。下一步：读 Distributor。
- 10:10 读完 Distributor 1-300（MerkleTree/Claim 结构、tree/lastTree、endOfDisputePeriod、claimed、claimRecipient、mainOperators、disputeTree、claim/claimWithRecipient/getMerkleRoot）。下一步：Distributor 300-558。
- 10:12 读完 Distributor 300-558（updateTree/resolveDispute/revokeTree/_claim/_revokeTree/_endOfDisputePeriod/_verifyProof）。四个重点：① _endOfDisputePeriod 向上取整到整点 + disputePeriod 默认 0 => 争议窗口可短至几十秒；② resolveDispute 押金判给 msg.sender(governor) 且无 nonReentrant；③ onClaim 空 catch + 回调传累计 amount 而只转 toSend；④ tx.origin 授权。下一步：读两个 interface + 定行号。
- 10:14 读完 IAccessControlManager.sol(21) / IClaimRecipient.sol(12)，并用行号探测把 11 条候选定位到具体行。开始落盘 CANDIDATES.md（分块写，避免一次性大字符串写入失败）。
- 10:17 CANDIDATES.md 落盘完成：11 条（H 0 / M 3 / L 8）+ 14 条显式否定 + 覆盖声明（代码本体 1,259 行）。下一步：核对文件完整性、清理探针文件、回报。

