# Cursor 回执：卡 47 新委托绑现在上架的专家版本（停在核对）

时间：2026-10-14 15:51（UTC+8）。停在「一、核对」。没有改钉、没有构建、没有晋级。没有 push，没有移动本待办。

## 停因

卡要求三个 `rev-parse` 分别为父仓 `cf7dfaaa…`、后端 `e937bbaa…`、网页 `6321e7c8…`；对不上就停，请所有者先同步 qwen。现场对不上：

| 仓 | 卡要 | 现场 HEAD |
| --- | --- | --- |
| investment-app | `cf7dfaaa5a4d4967dbef36c4b7536e98ee18f32e` | `dad004108eb5843f8492b960ee0bfec5b2e828d3` |
| investment-backend | `e937bbaafe3320a3e7d6f5b36aa345df15c4036b` | `260c3d907cf2b5e1c7447f8c7f397a0d76c3b47f` |
| investment-web-frontend | `6321e7c80a51f62ca8eca74aef79a95d48a91eb9` | `9337a2905c449d03771efb61e134e4ab6b68dbd8` |

三份期望提交在本地都还在（`cat-file -t` = `commit`），且是各自 HEAD 的父提交；现场 HEAD 已是下一张卡（新建项目 / 0024）那一版。`k8s` 分支 `qwen`、工作区干净；现钉仍是卡 45 的 `f5aaeba3…` / `d177b5e9…` / `e6963ddc…`；config `v7` / `'20261012_0018'`；`platform-status` 0。回退材料已备 `~/sunmoon-probe-runs/fin-forecast-pack-version-047/`（未用）。

请所有者把 qwen 工位的投资父仓/后端/网页同步（或检出）到卡 47 三钉后再通知续跑。

exit=1
