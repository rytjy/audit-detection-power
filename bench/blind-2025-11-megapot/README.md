# 盲测 #4 — C4 2025-11-megapot（H+M=11）

**开测时间 (UTC):** 2026-10-01T07:3xZ
**靶:** code4rena `2025-11-megapot` · Solidity · 官方分母 **H+M = 11**（"aggregated total of 11 unique vulnerabilities"）
**审计版本 commit:** `f0a7297d59c376e38b287b2c56740617dbbfbdc7`

## 污染检查（开测前）
- `validity_corpus/` · `drills/` · `answer_key/` **无 megapot 命中** ✅
- 本靶**从未读过**（bench 里此前只有 lido-2025-07 / hybra-2025-10 / sequence-2025-10；cabal-2025-04 只抓过 scope 页、未开测）
- **分母预验**（只取计数，不读正文）：`2025-11-megapot | aggregated total of 11`（同批：merkl 3 · cabal 8(仅 2 个 .sol ⇒ 弃) · garden 1 ⇒ 弃 · panoptic-hypovault 2 ⇒ 弃 · monetrix 1 ⇒ 弃 · k2 60(sol=0) ⇒ 弃）

## 哨兵规则（违反即作废）
1. **禁读** `code-423n4/2025-11-megapot-findings` 仓、官方 report 页正文、任何 findings/判级文本
2. 只读**代码**（`_repo/` 内 in-scope 文件）
3. 先出清单并落盘 → **之后**才准读官方材料；留 mtime 证据
4. 先验分母已完成（=11），不再回看报告页

## 已排除（消毒，防污染）
- `2025-11-megapot_V12.md`（V12 = 官方"已知/不给钱"清单 —— 最大泄漏源）
- `4naly3er-report.md`（自动工具报告）
- `Megapot v2 - Zellic Audit Report.pdf`（前序审计）
- `*-findings` 仓（**从未下载**）
保留：源码 + `documentation/` + `DOCUMENTATION.md` + `scope.txt`/`out_of_scope.txt` + sponsor `README.md`（与开赛时选手所见一致）

- 消毒后 tarball sha256 = `9cfcf7423e0ab352d93f6102591c95e512c87630b5377cb80f5a5b8f386b2ac7`（212,459 B）
- 原始 tarball sha256 = `48ea974bebe6e7646e87e5597bac888bda91924ac48d5de70decea49835b6a67`（VPS `codeload`）
