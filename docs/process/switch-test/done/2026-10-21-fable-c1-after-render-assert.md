# fable-c1 停在第二节：改后 `components-render OBJECT=all` 在 private_dir 断言失败

WS=fable，本地 Cursor，2026-10-21。卡 `docs/process/switch-test/inbox/cursor/2026-10-21-fable-c1-site-identity.md`（第二版 worktree 基线）。**改前基线已渲染成功；改后渲染 failed=1，字节对比未做。未改 C1 代码、未部署、未改 gitops 声明、未碰 Harbor/Jenkins 数据。卡仍留在 inbox/cursor/。**

## 现象（一句话）

C1 把 6 个应用后端 `config.yaml` 的 `private_dir` / `backup_dir` 改成含 `{{ cluster_name }}` / `{{ data_root }}` 的字面量；`common/backend/bind.yaml` 用 `lookup("file") | from_yaml` **重读**这些文件时 Jinja **不会展开**，随后 `prepare.yaml` 断言 `cfg.private_dir == '/etc/sunmoon/applications/' + cluster_name + '/' + application_name` 恒假。第一个跑到该断言的应用后端（RabbitMQ UI 路由渲染之后）即失败。

## 证据（原始输出）

```text
P=/home/zymun/sunmoon-probe-runs/c1-20261021-2008
改前 base = c2d0dbb5d（临时 worktree）
改后 HEAD = 7e0befc71（含 C1 76a6334f1；执行中途 origin/fable 又快进了 c0d 两提交，未碰 infrastructure/gitops）
集群：platform-status OBJECT=all → failed=0（开跑前）
```

### 卡命令补丁（写进回执；未改业务代码）

临时 worktree 冷目录缺两样，卡面只软链了 `.venv`/`.tools`，按「卡命令笔误可改」补了，否则改前也过不了：

1. `make services-chart` 先于 `components-render`（`services/README.md` 写明；否则缺 `.build/components/chart-source.yaml`）
2. 在 `$P/` 软链旁路应用仓（`knowfeed-app` 等 → `~/worktrees/fable/<同名>`），否则 `prepare.yaml` 读 migration head 时 `git -C .../knowfeed-app/knowfeed-backend` 找不到目录

### 改前（补丁后）——通过

```text
skipping: [localhost]

TASK [Copy only rendered declarations into the source tree] ********************
skipping: [localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=2599 changed=180  unreachable=0    failed=0    skipped=630  rescued=0    ignored=0   
```

`platform-plan OBJECT=all` → failed=0；`make config` 62 行。

### 改后——失败

```text

TASK [Require an explicit application bind] ************************************
ok: [localhost]

TASK [Bind application paths] **************************************************
ok: [localhost]

TASK [Load application configuration and locked images] ************************
ok: [localhost]

TASK [Combine public application identity] *************************************
ok: [localhost]

TASK [Derive public rollout identity] ******************************************
ok: [localhost]

TASK [Bind generic outbound service clients] ***********************************
ok: [localhost]

TASK [Bind generic inbound service relations from each caller's own declaration] ***
ok: [localhost]

TASK [Require every inbound relation to match exactly one enabled caller client] ***
skipping: [localhost]

TASK [Validate the selected deployment and identity boundaries] ****************
[ERROR]: Task failed: Action failed: Assertion failed
Origin: /home/zymun/worktrees/fable/sunmoonun/gitops/components/app-platform/common/backend/prepare.yaml:8:3

6   ansible.builtin.include_tasks:
7     file: '{{ components_root }}/app-platform/common/backend/bind.yaml'
8 - name: Validate the selected deployment and identity boundaries
    ^ column 3

fatal: [localhost]: FAILED! => {"assertion": "cfg.private_dir == '/etc/sunmoon/applications/' + cluster_name + '/' + application_name", "changed": false, "evaluated_to": false, "msg": "Assertion failed"}

PLAY RECAP *********************************************************************
localhost                  : ok=441  changed=25   unreachable=0    failed=1    skipped=87   rescued=0    ignored=0   

make: *** [Makefile:337: components-render] Error 2
```

### config.yaml 经 YAML 解析后的字面量（未进 Ansible）

```text
knowfeed: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowfeed'
knowfeed: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowfeed'
knowbase: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowbase'
knowbase: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowbase'
tpl: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/tpl'
tpl: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/tpl'
knowbench: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowbench'
knowbench: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowbench'
knowlab: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowlab'
knowlab: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowlab'
knowmart: private_dir='/etc/sunmoon/applications/{{ cluster_name }}/knowmart'
knowmart: backup_dir='{{ data_root }}/backups/applications/{{ cluster_name }}/knowmart'
```

加载路径（未改）：`gitops/components/app-platform/common/backend/bind.yaml` → `lookup("file", component_root + "/config.yaml") | from_yaml` → `cfg`；断言在 `common/backend/prepare.yaml` 第 24 行。

C1 `76a6334f1` 把 `private_dir` 从硬编码 `/etc/sunmoon/applications/sunmoon-kind/<app>` 改成 `/etc/sunmoon/applications/{{ cluster_name }}/<app>`；`private_dir` 断言本身在 C1 之前已是跨 `cluster_name` 核对，硬编码时能过，改成未展开模板后不过。

## 我这轮的边界

- 只读集群 + 渲染/plan/config；无 deploy、无改 gitops、无碰 Harbor/Jenkins 数据/密钥。
- 未就地改 C1 代码；未替所有者定判据/设计/修法。
- 卡未移 done/，仍在 `inbox/cursor/`。
- 产物目录 `$P`（含 before 完整渲染、after 失败日志）留在 `~/sunmoon-probe-runs/`，不进 git。
- 临时 worktree `$P/base` 已按卡第五节删除（比未完成也清掉，避免残留 detached worktree）。
- 本页 + `scripts/results/fable-c1.20261021-2028.md` 提交推 origin/fable。
