# qwen-003 C 段：在 k8s 里登记 knowlab、knowmart（Opus，远程机）

- **gitee 改公开**（Qwen，窗口回复）：8 个仓 `PATCH private=false` 全部 200，API 复核 private=False，匿名 `ls-remote` 都取到 master 提交号。
- **组件真源**：`gitops/components/app-platform/knowlab-app/`、`knowmart-app/` 照 tpl-app 写 `config.yaml`、`stage.yaml`、README（后端 database / migration / redis / rabbitmq / identity / runtime，前端 web、admin）；库 `knowlab`、`knowmart`，角色 `*_runtime` / `*_migrator`，Redis 前缀与 RabbitMQ vhost 同名，域名 `knowlab(-admin).sunmoonai.com`、`knowmart(-admin).sunmoonai.com`，Casdoor 浏览器应用 `sunmoonai-<名>-web/admin`（管理端 built-in、网页端 sunmoonai）。复制来的 README 里 tpl 的「已验」结论改成「尚未部署，待 D 段」。渲染产物（`workload.yaml`、`*.sops.yaml`、`image.lock.yaml`、`kustomization.yaml`、`stages.yaml`）由 D 段的 stage / build 生成。
- **枚举点**（只加两个名字，不改现有项）：`infrastructure/Makefile`（APP 校验、`CONFIG_FILES`、bootstrap / check / stage / build 链）、`host/deployment.yaml`（`PLATFORM_KNOWLAB*`、`PLATFORM_KNOWMART*`）、`applications/config.yaml`（`application_names`）、`deploy.yaml`、`verify.yaml`、`common/backend/bind.yaml`、`common/backend/domain/prepare.yaml`（两个应用的跨应用目标为空）、`entry/config.yaml`（两条新分流）、`check-browser.py`（同模板的「无业务 provider」检查）、两个构建测试的名单、`applications/README.md`、`gitops/components/README.md`；`applications/sources.yaml` 钉 B 段的 8 个提交。
- **没加的**：ELK 日志采集（改了采集器会滚动，不符合「现有对象一个不变」，记待办账 102）。
- **仓清单**：`switch-test/human-local.sh`、`human-remote.sh` 的父仓与子仓列表、`switch-test/align_workstations.sh` 的 `REPOS` 加上两个新仓。
- **远程机挂仓**：`~/master/knowlab-app`、`knowmart-app` 与五个工位各一个同名分支，子仓同名分支、推送地址 GitHub + gitee；`align_workstations.sh list` 两个新仓 48 个检出全 ok。
- **检查**（远程机能跑的）：改动的 YAML 全部能解析；`check-browser.py` 与测试语法通过；`make -n application-deployment-plan APP=knowlab` 接受、`APP=other` 被拒（提示含新名单）；`test_python_sources.py` 5 个全过（挂仓前两个新应用找不到 `pyproject.toml`，挂仓后通过）；`test_build_selection.py` 失败 15 个，全是同一条既有断言（改动前同一提交上就失败 9 个，记待办账 103）。
- **现有应用渲染不变**这一项要读本地机私有输入，放到 D2 在本地机做。
