# PREREG — blind-2025-merkl（2026-11-01 冻结）

## 1. 靶与分母口径（只看总数，不读正文）
- 靶 slug：`2025-11-merkl`（code-423n4/2025-11-merkl，非 -findings）
- 官方 "aggregated total of N unique vulnerabilities" = **N = 3**
- 分母定义：**[x] 仅 H+M** —— 3 条，构成 **0H / 3M**（依据：bench/README 前批预验 + 本次页面仅计数）
- QA 未逐条公开 ⇒ 结论必须标「**上界**」
- 取码：codeload tar.gz，`sha256 53ecef61675bed4930d66b2436583ac287b451162c36868cdddea96f1b969a42`（1,584,983 B）

## 2. 命中判定规则（逐字写死，事后不得改）
- **严格命中** = 候选主诉机制与官方某条机制一致（file:line 量级对得上）
- **部分命中** = 候选里**任一条断言**（含"附带说明"/二级观察）命中官方某条的机制
- **未收录** = 不命中任何官方 H/M 条目
- 多对多：① 一条候选命中两条官方 ⇒ 计 **1 次命中**（记在最强那条），另一条记"冗余覆盖"；② 两条候选命中同一条官方 ⇒ 计 **1 次命中**，另一条记"重复候选"，**不计入命中**，但**仍计入候选总数**（影响 1−精确率）
- 命中判定人：父线程（被测方）· 第三方重判：**否**

## 3. 严重度口径
- 只记**方向**（我们档 vs 官方档：同档 / 判高 / 判低），**不做 ±1 折算**
- 我们一条 High 都没给时：记为"**无 High 候选**"，不折算成 M

## 4. 读者 / 时间盒 / 干预
- 读者：**1 个隔离子线程**（context=isolated，禁嵌套 spawn，禁联网）
- 时间盒：**60 分钟**
- 是否带判据清单：**[x] OFF 无**（与 hybra / sequence / megapot 基线一致）
- 允许读：`_repo/contracts/DistributionCreator.sol` · `_repo/contracts/Distributor.sol` · `scope.txt` · `out_of_scope.txt` · `README-sponsor.md` · `docs/`：**否**
- 每靶重复次数：**1**（n=1 ⇒ 必须给 Wilson 95% CI，方向性结论不成立）

## 5. 禁止事项（违反 ⇒ 作废）
- 不读：任何 `*-findings` 仓 / official report / `2025_11_merkl_v12.md` / `4naly3er-report.md` / `audits/` / `discord-export/`
- 不联网搜索该靶；不读 `validity_corpus/` `drills/` `answer_key/`
- 先落盘候选清单 + `FREEZE.md`（sha256+mtime），**之后**才准抓官方 report

## 6. 交叉靶比较的免责（结论必带）
- 跨靶比较只能写"本次产出"，**不得**写"能力变好/变差"（分母/靶域/时间盒/读者/规则全在变）
- 样本不足必须给 **Wilson 95% CI**
