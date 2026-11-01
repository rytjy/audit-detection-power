# 盲测 #3 — C4 2025-10-sequence（H+M=6）

**开测时间 (UTC):** 20261001T055244Z
**靶:** code4rena 2025-10-sequence · Solidity · 官方分母 **H+M = 6**（"aggregated total of 6 unique vulnerabilities"）
**污染检查:** 我们的语料（validity_corpus/ · drills/ · answer_key/）**无 sequence 命中**；本靶**从未读过**
**哨兵规则（违反即作废）**
1. **禁读** `code-423n4/2025-10-sequence-findings` 仓、官方 report 页、任何 findings/报告文本
2. 只读**代码**（`src/` 等 in-scope 文件）
3. 先出清单并落盘 → **之后**才准读官方材料；留 mtime 证据
4. 先验分母已完成（=6），不再回看报告页

## 已排除（消毒，防污染）
- `*-findings` 仓（**从未下载**）
- `discord-export/`（赛期讨论含结论）
- `audits/`（3 份前序审计 PDF/MD）
- `4naly3er-report.md`（自动工具报告）
- `Sequence-V12-output.md`（**V12 = 官方"已知问题/不给钱"清单** —— 最大的泄漏源）
保留：源码 + `docs/` + `scope.txt`/`out_of_scope.txt` + sponsor README（与开赛时选手所见一致）
tarball sha256 = `97349403faf5c56b4760ae1d2f62f388993cf27a6a353fcd537e1ed0976ca53d`
