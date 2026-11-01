# 盲测冻结记录（blind-2025-merkl）

- 冻结时刻 (UTC): 2026-11-01T02:0xZ
- 靶: code-423n4/2025-11-merkl（**非** -findings）
- 分母预验（仅计数，早于任何阅读）: `aggregated total of 3 unique vulnerabilities.` ⇒ N=3（0H/3M，上界口径）
- 取码: codeload tar.gz · 1,584,983 B · sha256 `53ecef61675bed4930d66b2436583ac287b451162c36868cdddea96f1b969a42`
- 消毒: 已删 `2025_11_merkl_v12.md` · `4naly3er-report.md` · `discord-export/`（记录在 PROGRESS）
- 在 scope 文件: contracts/DistributionCreator.sol (668 L) · contracts/Distributor.sol (558 L) = 1,226 行

## PREREG（判分规则）冻结
- PREREG.md mtime: 2026-11-01 10:03:49 +0800
- PREREG.md sha256: `151c5272f77a7edfd835e4e80cd1a3dfcaa23ad25fe476ae4bf32318b1b2a819`
- 冻结时间**早于**候选清单与官方 report 抓取 ⇒ 成立

## 候选清单冻结（子线程完成后补）
- CANDIDATES.md: 待填
- 官方 report 抓取: 待候选清单落盘之后

## 候选清单冻结（子线程完成）
- CANDIDATES.md mtime: 2026-11-01 10:09:56.110632184 +0800
- CANDIDATES.md sha256: `8f22d5c22d5a95625fe5316aec1f5fd99e68295a08150c5b8f1feac50cce53c7`
- PROGRESS.md mtime: 2026-11-01 10:09:44.620605170 +0800
- PROGRESS.md sha256: `3df3b2a57057834256e85cb2865e04655c844c01c0f57e7595f611f7c00859d0`
- 官方 report 抓取: 在本行之后（时间戳见下）
- 官方 report 抓取时刻: 2026-11-01T02:10:16Z
