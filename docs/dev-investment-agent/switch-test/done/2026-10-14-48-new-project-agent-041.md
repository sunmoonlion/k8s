# Cursor 发布卡：电脑代理 0.4.1（新建项目：建文件夹、拉取仓库）+ investment 新建项目对话框与登记前核目录（0024）

```text
被测仓：k8s，qwen 工作树 `~/worktrees/qwen/k8s`，分支 qwen
跑：先第一部分（代理），application-check 退出 0 后再第二部分（应用）；两部分各自 stage、各自发布
仓与提交：代理 runtime qwen 头 76832a8（76832a8da4e65a8692fac453c35b5ef2081d0090，0.4.1；代理源码与 f09ec89 相同，之后只加了 Qwen 回执与测试的 Windows 跳过）
          投资父仓 dad004108eb5843f8492b960ee0bfec5b2e828d3；后端 260c3d907cf2b5e1c7447f8c7f397a0d76c3b47f；网页 9337a2905c449d03771efb61e134e4ab6b68dbd8；管理端不动
预计：代理 60–90 分钟 + 应用 30–45 分钟；两次现网变更；没有新迁移，config 仍 v7 / '20261012_0018'
看什么：代理——zip 组出、windows-candidate pass（0.4.1 / 文件数 109）、upload readback_verified、agent-releases 六项换 0.4.1；
        应用——后端与网页两个 image.lock 变、计划核到 '20261012_0018'、迁移 Job 名结尾仍 -v7、application-check 0
前提：所有者已通知执行；**卡 47 已上线**（现钉父仓 cf7dfaaa / 后端 e937bbaa / 网页 6321e7c8）；
      **Qwen 卡 0024 段 2（Windows 真机）回执已由远程审过、结论通过**（探针 12 项全过；Windows 全量单测 337 过，
      19 项失败已判明：10 项是新测试的 Linux 夹具，已在 76832a8 标为 Windows 跳过；9 项是 0.4.0 起就有、源码未变的
      localApi / service 夹具问题，不阻塞）；
      ~/worktrees/qwen/k8s 在 qwen 且干净、含本卡；platform-status 0；Harbor 在；不碰旧 kind；不退回
回传：k8s/scripts/results/new-project-agent-041-cursor.<时间>.md（只收文本；zip、回退材料放 ~/sunmoon-probe-runs/）。本地提交，不 push
```

## 这一轮是什么

10-14 现网：所有者新建项目「财务预测」（`C:\Users\zymun\Desktop\myproject`），工作台只登记了路径，电脑上没有这个文件夹；工作对话写 `hello.txt` 时代理反复报 Windows 工作目录不存在，模型转去请求提权，什么都没做成。所有者定：新建时在电脑上建好；可以拉 git 仓库，已有登录先用，没有就弹框填令牌；ssh 到远程以后再说。设计 `tree-build/SDD/modules/0024-new-project.md`。

- **代理 0.4.1**（runtime `76832a8`，代理源码同 `f09ec89`）：回环口加 `POST /local/v1/projects/folder`、`/projects/clone`（门同 0022：Origin + 本机访问票），`info.capabilities` 多 `local-project-v1`。只写工作区；Windows 建文件夹走文件助手已审的 `fs/createDirectory`；clone 由代理直接调 git（不经 shell，只放行 https/ssh，不拉子模块），令牌只进 git 子进程环境。包内文件 108 → **109**（新增 `localProjects.js`）；依赖锁、Codex 0.155.1、Node 24.19.0、`install.ps1.tmpl` 都不变（sha256 仍 `49e62ae1519be256531555461ded173d6d8f32c27fba0909c4fd3f9f83435923`）。
- **后端 `260c3d9`**：新建项目登记前经服务流 `fs/getMetadata` 核目录，明确不在就不登记（409 `project_directory_missing`）；问不到照登记。
- **网页 `9337a29`**：新建项目对话框两个标签「新建文件夹」「拉取仓库」，先请本机代理做、成功再登记；仓库要登录时展开令牌框；代理不在 / 旧版直接说明、不能建。

后端全量 1004 过（连真 PostgreSQL）；网页 263 过、`next build` 过；代理 Linux 323 过 / 34 平台跳过。

**先发代理、后发应用**：网页新对话框要 0.4.1 才能建项目（旧代理会显示「要更新到 0.4.1」）；后端核目录对旧代理也兼容。

**停下的规则**：任何一步退出码不是 0，就停在那一步，把输出贴进回传，不做退回。

---

# 第一部分：代理 0.4.1

## A：组包（Windows 侧，runtime 76832a8）

1. 核 runtime Windows checkout：`git rev-parse HEAD` = `76832a8da4e65a8692fac453c35b5ef2081d0090`、`git status --porcelain` 干净；依赖目录完整（含 `smol-toml`）。
2. 用 0.4.0 同一套物料组包，输出到**新目录**：

```bash
node agent/distribution/build.mjs \
  --node-exe <official node.exe v24.19.0> \
  --dependencies <0.4.0 同一 frozen Windows 依赖目录> \
  --site <investment 生产 profile.json> \
  --ca-pem <bundled CA pem> \
  --output <新目录，如 C:\Users\zymun\sunmoon-probe-runs\windows-agent-041-release\sunmoon-agent-76832a8>
```

   记录 `manifestSha256`、`sourceRevision`（须 = `76832a8da4e65a8692fac453c35b5ef2081d0090`）、`files`（应是 **109**）、`bytes`。不是 109 就停下，把 `app/dist` 下的文件名列进回传。
3. 用**包内 Node** 跑 `windows-candidate.mjs`：须 `result: pass`、agent 0.4.1、codex 0.155.1、node 24.19.0、文件数 109、未启动代理。
4. 打成 `sunmoon-agent-0.4.1-76832a8-windows-x64.zip`，记 **ZIP SHA256** 与 **size_bytes**。对象键 `windows-x64/0.4.1/sunmoon-agent-0.4.1-76832a8-windows-x64.zip`。

## B：校验并上传（只有 A 全过才执行）

```bash
AGENT_ZIP=<zip 绝对路径> make -C infrastructure agent-release-verify
AGENT_ZIP=<zip 绝对路径> make -C infrastructure agent-release-upload
```

核 verify 通过、upload `uploaded:true` 且 `readback_verified:true`。任何不符立即停；不关 TLS、不扩权、不覆盖对象、不删桶。

## C：换 0.4.1 并只发投资（只有 B 全过才执行）

1. `agent-releases/config.yaml` 六项：`version: 0.4.1`、`source_revision: 76832a8da4e65a8692fac453c35b5ef2081d0090`、`object_key` 如上、`zip_sha256` / `manifest_sha256` / `size_bytes` 用实测值；`codex_version`、`enabled`、`download_available` 不变。
2. 核对 k8s 那份 `install.ps1.tmpl` 与 runtime `agent/distribution/install.ps1.tmpl` sha256 都是 `49e62ae1…`，无 BOM；不同立即停。
3. `make -C infrastructure application-stage APP=investment`、`application-deployment-plan APP=investment`；审 diff：只动 `config.yaml`、`agent-releases.sops.yaml`、`workload.yaml`（四处 `config-sha256`），后端镜像未换。提交 `deploy(investment): 代理 0.4.1（待办 48 代理）`，`flux-release`，晋级（`release(kind): 晋级到 <短号>（待办 48 代理）`），`flux-source-apply` / `flux-source-status` / `application-check APP=investment` 退出 0。

---

# 第二部分：应用（只有第一部分 application-check 退出 0 才开始）

## 一、核对（只读）

```bash
cd ~/worktrees/qwen/k8s && git branch --show-current && git log --oneline -1 && git status --short | head -5
grep -n "investment:" -A7 infrastructure/applications/sources.yaml
grep -n "expected_schema_revision\|migration_job_revision" gitops/components/app-platform/investment-app/investment-backend/config.yaml
git -C ~/worktrees/qwen/investment-app rev-parse HEAD
git -C ~/worktrees/qwen/investment-app/investment-backend rev-parse HEAD
git -C ~/worktrees/qwen/investment-app/investment-web-frontend rev-parse HEAD
make -C infrastructure platform-status; echo "exit=$?"
```

要看到：现在钉的是父仓 `cf7dfaaa…`、后端 `e937bbaa…`、网页 `6321e7c8…`（卡 47）；config 是 `v7` / `'20261012_0018'`；三个 `rev-parse` 是 `dad00410…`、`260c3d90…`、`9337a290…`（不是就停，请所有者先同步 qwen）；`platform-status` 0。

## 二、改钉（只动父仓、后端、网页五行）

```bash
python3 - <<'PY2'
import re,pathlib
p=pathlib.Path('infrastructure/applications/sources.yaml'); s=p.read_text()
m=re.search(r'(?ms)^  investment:\n(?:(?!^  \S).*\n?)*', s); assert m
block=m.group(0); new=block
new=re.sub(r'(?m)^(    parent_revision: )\w+', r'\g<1>dad004108eb5843f8492b960ee0bfec5b2e828d3', new, count=1)
new=re.sub(r'(?m)^(    backend_parent_revision: )\w+', r'\g<1>260c3d907cf2b5e1c7447f8c7f397a0d76c3b47f', new)
new=re.sub(r'(?m)^(    backend_revision: )\w+', r'\g<1>260c3d907cf2b5e1c7447f8c7f397a0d76c3b47f', new)
new=re.sub(r'(?m)^(    web_parent_revision: )\w+', r'\g<1>9337a2905c449d03771efb61e134e4ab6b68dbd8', new)
new=re.sub(r'(?m)^(    web_revision: )\w+', r'\g<1>9337a2905c449d03771efb61e134e4ab6b68dbd8', new)
assert new!=block; p.write_text(s.replace(block,new,1))
PY2
git diff --stat; git diff infrastructure/applications/sources.yaml | grep "^[-+]" | grep -v "^+++\|^---"
```

要看到：只动这一份文件、五行；`admin_*` 不变。

## 三、构建、暂存、计划

```bash
make -C infrastructure platform-build OBJECT=app-platform/investment-app 2>&1 | tail -n 12; echo "exit=${PIPESTATUS[0]}"
for f in $(git diff --name-only gitops/components/app-platform/investment-app | grep image.lock); do echo "$f: $(grep -E 'source_revision' $f | head -1)"; done
make -C infrastructure platform-stage OBJECT=app-platform/investment-app; echo "exit=$?"
grep -rn "BEGIN PRIVATE KEY\|BEGIN PUBLIC KEY" gitops/ | head -3   # 必须没有
git diff gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml | grep -E '^[-+].*(investment-migrate-|image: )' | head -8
make -C infrastructure application-deployment-plan APP=investment 2>&1 | grep -E "schema|revision|ok=|failed=" | tail -4; echo "exit=${PIPESTATUS[0]}"
```

要看到：后端与网页两个 `image.lock.yaml` 变（`source_revision` = `260c3d90…`、`9337a290…`）；管理端锁不变；没有 PEM；迁移 Job 名结尾仍 `-v7`；计划核到 `20261012_0018`。

## 四、提交、发布、晋级、检查

```bash
git add infrastructure/applications/sources.yaml gitops/components/app-platform/investment-app
git -c core.editor=true commit -m "deploy(investment): 新建项目先请代理建好文件夹或拉好仓库、登记前核目录（待办 48 应用）"
make -C infrastructure flux-release; echo "exit=$?"
sudo cat infrastructure/.build/flux/source-candidate.yaml; git rev-parse HEAD
sudo cat infrastructure/.build/flux/source-candidate.yaml | sudo tee infrastructure/environments/kind/flux-source.yaml >/dev/null
sudo chown "$(id -u):$(id -g)" infrastructure/environments/kind/flux-source.yaml 2>/dev/null; git diff infrastructure/environments/kind/flux-source.yaml
git add infrastructure/environments/kind/flux-source.yaml && git -c core.editor=true commit -m "release(kind): 晋级到 $(git rev-parse --short HEAD)（待办 48 应用）"
make -C infrastructure flux-source-apply; echo "exit=$?"
make -C infrastructure flux-source-status; echo "exit=$?"
make -C infrastructure application-check APP=investment; echo "exit=$?"
export KUBECONFIG=~/.kube/sunmoon-kind.config; K=$(command -v kubectl || echo infrastructure/.tools/bin/kubectl)
$K -n app-platform-dev get pods | grep -E "investment-(backend|migrate|web)" | head -14
```

## 验收

- 代理：zip 组出、candidate pass、109 文件；verify / upload `readback_verified:true`；六项 = 0.4.1；`application-check` 0。
- 应用：钉 = 父仓 `dad00410…`、后端 `260c3d90…`、网页 `9337a290…`；管理端不变；`application-check` 0。
- **真人验收由所有者做，不在本卡**（先把电脑上的代理升到 0.4.1）：
  1. 新建项目 →「新建文件夹」填 `myproject2`：桌面上真的多出这个文件夹，项目登记成功；新开工作对话让它写 `hello.txt`，一次写成。
  2. 「拉取仓库」填一个公开仓库：拉下来、项目登记成功，子目录默认是仓库名。
  3. 「拉取仓库」填一个私有仓库（电脑上没登录过）：对话框展开「这个仓库要登录」，填令牌后拉下来；勾了「记住」的，再拉同一主机的仓库不再问。
  4. 在没装代理的设备上打开新建项目：说「要在装着代理的那台电脑上新建」，不能建。
  5. 旧项目「财务预测」（电脑上没有文件夹）：可以删掉它，用「新建文件夹」重建。

## 失败回退与交回

任一步失败停在原步，保留错误输出与候选。需恢复时：代理回 0.4.0 六项；应用把五行改回 `cf7dfaaa…` / `e937bbaa…` / `6321e7c8…`，重走构建到晋级。报告写 `k8s/scripts/results/new-project-agent-041-cursor.<时间>.md`，最后一行 `exit=<码>`；本地提交，不 push、不移动本待办。
