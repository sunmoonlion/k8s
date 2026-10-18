# qwen-007 发布回执（本地机 Qwen）——第三节 build knowlab exit=2 停点

- 派活卡：`docs/dev-investment-agent/switch-test/inbox/qwen/2026-10-18-qwen-007-release.md`
- 执行者：Qwen（本地机）；停点时间 2026-10-18 19:02
- 停点规则：卡「任何一步 exit 不是 0 就停，输出原样进回执，不重试、不退回」——**第三节停止，不重试、不退回；第四、五节未执行**

## 1. 各步 exit

| 节 | 命令 | exit |
| --- | --- | --- |
| 一 | `git pull --ff-only origin qwen`（k8s 到 `95c437bb`，与卡要求一致） | 0 |
| 一 | 五父仓 fetch/checkout/pull/submodule update | 全 0 |
| 一 | 五父仓 HEAD 与十五子仓指针核卡表 | 逐字一致（见 §2） |
| 一 | 迁移头配置五值核卡 | 逐字一致（见 §2） |
| 一 | `make -C infrastructure platform-status` | 0（PLAY RECAP failed=0） |
| 二 | 卡内 python 改钉脚本 | 0（`pin exit=0`；只动 sources.yaml；加行计数 `31`） |
| 三 | `platform-build` knowlab | **2 → 停**（原文见 §3） |
| 三 | 其余四构建、五暂存、五计划 | 未执行（脚本按卡序自停） |
| 四、五 | 未执行 | — |

## 2. 第一节核对结果（与卡表逐字一致）

- knowbench 父 `4bee41aa7ef35c699838940a82e6a6c8602b6aca`：管 `26964553…`、后 `68b59249…`、网 `96323721…`
- knowlab 父 `06e78408f6769a4f31cae50582f7f3b92e8bdf58`：管 `fc445354…`、后 `836587c8…`、网 `e9bb849c…`
- knowmart 父 `463384baca0cd12725088f672f821bdcc9c78348`：管 `107fda29…`、后 `c00eebf3…`、网 `5ef6a080…`
- knowfeed 父 `808b7e1de97272f4376674f58907e94896e29d0e`：管 `b344c106…`、后 `6239d224…`、网 `bca159f7…`
- knowbase 父 `a5051faf4c086e4d282217ce0e8225b4ec39bf8d`：管 `f0974950…`、后 `ad1e2edc…`、网 `8c338db2…`
- 迁移头配置：knowbench `20261017_0020`、knowlab `20261018_0007`、knowmart `20261018_0006`、knowfeed `20261015_0014`、knowbase `20260927_0007`

## 3. 停点原文（build knowlab，exit=2）

```text
TASK [Require Windows growth budget before writing] ****************************
[ERROR]: Task failed: Module failed: The command exited with a non-zero return code.
Origin: /home/zymun/worktrees/qwen/k8s/infrastructure/host/tasks/capacity.yaml:47:3
fatal: [localhost]: FAILED! => {"changed": false, "cmd": ["…powershell.exe", "-NoProfile", "-NonInteractive", "-File", "C:\\wsl-disks\\scripts\\platform-kind-v1\\windows-capacity.ps1", "-DataVhdPath", "C:\\wsl-disks\\sunmoon-data.vhdx", "-DataMaximumGiB", "230", "-MinimumFreeGiB", "10", "-PlannedBytes", "6442450944"], "rc": 2, "stdout": "{\"checked_at_utc\":\"2026-10-18T11:00:21.2925097Z\",\"c_free_bytes\":80938209280,\"data_vhd_length\":180594147328,\"data_vhd_allocated_bytes\":180594147328,\"configured_data_maximum_bytes\":246960619520,\"future_data_growth_bytes\":66366472192,\"planned_bytes\":6442450944,\"remaining_after_growth_and_plan_bytes\":8129286144,\"minimum_free_bytes\":10737418240,\"passes\":false,\"scope\":\"Configured VHD growth plus requested operation; excludes other future system disk growth\"}"}
PLAY RECAP *********************************************************************
localhost                  : ok=12   changed=0    unreachable=0    failed=1    skipped=4    rescued=0    ignored=0
make[2]: *** [Makefile:343: application-build-web] Error 2
make[1]: *** [Makefile:503: platform-build-selected] Error 2
make: *** [Makefile:487: platform-build] Error 2
exit=2
```

（cmd 中 powershell 路径按抹敏惯例缩略；stdout JSON 为容量检查完整输出，原样保留。）

## 4. 根因（只读判读，未改任何配置）

- 闸门是宿主机容量检查（`infrastructure/host/tasks/capacity.yaml:47` → Windows 侧 `windows-capacity.ps1`），不是代码或清单问题。
- 算术：C 盘空闲 `80938209280`（约 75.4 GiB）；数据 VHD 已全量分配 `180594147328`（约 168.2 GiB），配置上限 `246960619520`（230 GiB）→ 未来增长 `66366472192`（约 61.8 GiB）；本次构建计划 `6442450944`（6 GiB）；扣完剩 `8129286144`（约 7.6 GiB）< 下限 `10737418240`（10 GiB）→ `passes:false`。
- 即：C 盘剩余不够同时覆盖「VHD 长到配置上限」与「本次 6 GiB 构建」再留 10 GiB 余量。处置选项（清 C 盘、调低 DataMaximumGiB、 compact VHD 等）属宿主机配置，交 Opus/所有者定，我不擅动。
- 停点前进度：knowlab **backend** 构建已成功并写锁（`gitops/…/knowlab-backend/image.lock.yaml` 已变）；knowlab **web** 构建在容量闸门处失败；其余应用未开始。

## 5. 现场状态（不退回）

- `infrastructure/applications/sources.yaml` 已按卡改钉（31 行，未提交）
- `gitops/components/app-platform/knowlab-app/knowlab-backend/image.lock.yaml` 为 knowlab backend 构建产物（未提交）
- 未 commit、未 release、未 apply、未 push；第四节命令未执行
- 一次性脚本 `/tmp/q007-s3.sh`、日志 `/tmp/q007-s3.log`、`/tmp/q007-status.log`、`/tmp/q007-build-knowlab.log` 留在 /tmp（DeleteFile 够不着 /tmp，按纪律不用 shell rm，如实报告；工位顶层无残留）

exit=2（build knowlab 容量闸门；第一、二节全 0）
