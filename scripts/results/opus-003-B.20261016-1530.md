# qwen-003 B 段：实例化 knowlab-app、knowmart-app 并推代码（Opus，远程机）

- **先修模板**：tpl-app 的 `init.sh` 跑不通（两处缺陷：`find` 的排除条件写在 `-print0` 之后不生效，把子仓的 `.git` 指针文件改坏；先写 `.gitmodules` 再 `git mv` 被 git 拒绝，且制表符写成了字面 `\t`）。改为先 `git mv`、再用 `printf` 整份重写 `.gitmodules`，排除条件移到 `-print0` 前；在临时目录用新克隆验证通过。tpl-app `qwen` `4b19daf`。
- **实例化**：从 GitHub 克隆 tpl-app `qwen`（`4b19daf`，连子仓）到临时目录，跑 `init.sh knowlab|knowmart sunmoonlion`；子仓里不剩 `tpl` 字样；每个子仓一个提交「实例化 …：由 tpl-<组件> <提交> 经 tpl-app init.sh 生成」。父仓去掉模板专用与旧体系部署文件（`init.sh`、`verify_template_release.py`、`template-release-manifest.json`、两份前端矩阵、`k8s-deployment/`、`dev-to-prod-deploy/`、`build-image.md`、`自动注册.md`、`development-source-lock.json`、`contracts/`，各组件都不依赖），README 写明定位，`AGENTS.md`、`CLAUDE.md`、`.cursor/rules` 沿用模板（已指向 k8s 现行文档）。
- **测试**（临时目录）：knowlab 后端 `pytest` 257 passed、88 skipped（跳过的要数据库）；网页端 `tsc` 通过、`vitest` 81 passed / 2 skipped；管理端 `tsc` 通过、`vitest` 44 passed。knowmart 后端 257 passed、88 skipped（前端与 knowlab 同一份模板代码，只差名字）。`next build` 留给发布链的 `platform-build`。
- **推送**：子仓先、父仓后，`master`；推送地址 GitHub + gitee 两个。逐个 `ls-remote` 核对两边 master 都等于本地提交：

| 仓 | 提交 |
| --- | --- |
| knowlab-backend | a984354 |
| knowlab-admin-frontend | dc58a86 |
| knowlab-web-frontend | 8347abe |
| knowlab-app | a7d9e71 |
| knowmart-backend | 22fa400 |
| knowmart-admin-frontend | eefa294 |
| knowmart-web-frontend | 39a6fca |
| knowmart-app | 3377874 |

- 实例化脚本留在远程机临时目录，不入库（一次性；以后再实例化直接用修好的 `tpl-app/init.sh`）。
- 剩一件交给 Qwen：gitee 8 个仓现在有内容了，改公开。
