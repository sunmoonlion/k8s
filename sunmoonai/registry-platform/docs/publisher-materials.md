# 发布工具离线物料与独立运行目录

更新：2026-09-28。本地/云主机共用 Ubuntu 24.04 amd64 物料准备和运行目录生成方法；云端实际部署未经实机验证。

## 已准备的实际批次

| 项目 | 值 |
| --- | --- |
| 正式物料根 | `/home/zymun/packages-to-be-installed/releases/registry-publisher-linux-amd64` |
| Ubuntu 快照 | `20260927T000000Z`，noble/main+universe、updates、security |
| 工具包 | `skopeo 1.13.3+ds1-2ubuntu0.24.04.3`；运行输出 `skopeo version 1.13.3` |
| APT 根依赖 | skopeo、ca-certificates；空 dpkg status 解析完整依赖，78 个包 |
| 包文件总量 | 32,171,430 B；签名索引 9 份、112,150,216 B |
| 实际回传量 | 241,212,837 B，含 APT 缓存、下载日志和证据；没有删除源文件 |
| 运行目录 | `runtime/`，80 个普通文件和 53 个库别名，普通文件 50,437,568 B |
| 启动器 | `runtime/bin/skopeo`，SHA256 `29a058c573fdf6be3f06178202e707ad97ed132b88182e765ec9289d0bd72490` |
| 运行锁 | `runtime/runtime.lock.json`，SHA256 `f5aea7d4b012a76ae03f4ea0074ed29653a4b1a2a49c838e6124a808a514fd77` |
| Ubuntu 包锁 | SHA256 `34155c0f648c5e9f628fabad540737b706366c2106407f869f798ffc8e833d66` |

公开锁副本：[Ubuntu 包](../publisher-os.lock.json)、[运行文件](../publisher-runtime.lock.json)。
选择的是当前 Ubuntu 24.04 快照中的发行版补丁包；所需参数已通过固定版本源码与真实二进制帮助查询核对。
Skopeo 的版本号独立于 Kubernetes，不改变 Kubernetes 或数据库/Harbor 服务版本。

## 可重复的准备方法

1. **下载到独立新批次。** 在可信 Ubuntu 24.04 amd64 下载机运行同一 `infrastructure/materials/prepare_os.py`：

   ```bash
   python3 -B sunmoonai/infrastructure/materials/prepare_os.py \
     --package-set registry-publisher \
     --root /absolute/new-batch/ubuntu-24.04-amd64-20260927T000000Z --apply
   ```

   默认不加 `--apply` 只打印。使用独立 sources/cache/status、官方签名 keyring，下载-only；不安装系统包。
   原集群依赖集合仍是默认 `--package-set cluster`，原锁和目录不混用。
   下载记录包含 root packages 和 keyring SHA；同一路径混用不同集合会拒绝。

2. **回传并重新核验。** 保留包、9 份签名索引、锁与下载证据，rsync 可续传，不用 `--delete`。
   本批东京临时根为 `/home/zym/sunmoon-registry-publisher-20260928-v1`；独立下载程序也在该目录。
   本机重新执行：

   ```bash
   python3 -B sunmoonai/infrastructure/materials/verify_os.py \
     --root /absolute/new-batch/ubuntu-24.04-amd64-20260927T000000Z \
     --lock /absolute/new-batch/ubuntu-24.04-amd64-20260927T000000Z/os-dependencies.lock.json
   ```

   三份 Release 签名、Release→Packages→每个 deb 的摘要/身份链均须通过。
   现有核验器会拒绝过期的签名索引；将来重新准备时显式选择有效快照并重新形成锁，不关闭有效期检查。

3. **生成独立运行目录。**

   ```bash
   ./sunmoon harbor publisher-runtime \
     --source /absolute/new-batch/ubuntu-24.04-amd64-20260927T000000Z \
     --output /absolute/new-batch/runtime --apply
   ```

   先核同一签名和包链，只选取 Skopeo ELF 与所需共享库；不执行包安装脚本，不写 `/usr` 或 `/etc`。
   启动器每次检查运行锁、80 个文件摘要/大小及库别名，然后通过批次自带 loader/library-path 执行。
   输出目录已存在时拒绝覆盖。失败残留先保留检查，不自动清理或重建。
   生成过程拒绝 root；运行前置为 Linux amd64、Python 3.11+，本次在 WSL Ubuntu 24.04/Python 3.12 完成。
   DNS、网络、CA 及内核仍由宿主提供；需要 GPG 等外部签名工具的其他策略须另行验证。

4. **记录能力与准备发布批次。** 查询 `runtime/bin/skopeo --version` 和 `copy --help`，核固定参数；
   用已有已锁 OCI 归档只读查询 manifest 摘要，再形成发布 JSON。工具启动器 SHA 本身包含对运行锁的绑定，不能只替换库却沿用旧启动器。
   新机器路径可不同；调整实际批次路径并重核配置摘要，不能将本地绝对路径当作云端可用路径。
   可以完整复制已准入的 `runtime/`（保留内部库别名），启动器按锁复核所有字节，无需在新机重新联网解析依赖。
   若从包重新生成运行目录，仍执行上述签名索引有效期检查；过期时重新准备有效批次，不能临时关闭保护。

本批回传前 C 盘可用 94,775,484,416 B，数据 VHDX 文件 93,050,634,240 B；
按数据盘增长到 100 GiB、工具预留 1 GiB 计算后仍可用 79,378,194,432 B，满足至少 50 GiB 要求。
这只是当时容量核对，后续发布仍要按实际工作目录重查空间。

## 第一份真实发布批次

[publication-traefik-local.json](../config/publication-traefik-local.json)使用已有 Traefik v3.7.13 OCI 文件，未重新下载或转换镜像。
归档 SHA `f2ac4906393fa1fa0dd40c3b664a192c838c0c84f0a75e744c575b526f4be50d`、55,225,344 B，
实际 Skopeo 读取 manifest 为 `sha256:3429c14149401de2ac82fc72ddc6a92642332b90deb3012301ff211b9d2d0f18`，与原入口镜像锁一致。

[策略](../config/publication-traefik-policy.json)默认拒绝，仅允许该绝对 OCI 归档路径。
其 `insecureAcceptAnything` 是 containers/image 对“不要求此归档携带签名”的策略类型名；
本批信任依据是已批准来源和归档/manifest SHA，**没有声明已验证镜像发布者签名**。
这不改变 TLS 设置，实际仓库连接仍强制校验 CA/域名；发布器另行核全部文件与 manifest SHA。
策略作用域依据 [官方 policy 格式](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)。

默认计划：

```bash
./sunmoon harbor publish --batch "$PWD/sunmoonai/registry-platform/config/publication-traefik-local.json"
```

公开 Harbor 仍是旧 KIND；尚未准备此次正式推送的账号/维护准入和工作目录，也未执行 `publish --apply`。
这里不自动建 tag、切换入口或修改集群。下一步是发布运行条件及整链验收，不应把 manifest 读取成功当作真实推送成功。

## 最终清理与保留

正式工具包、索引证据、运行锁和运行目录保留在唯一物料根。
东京 `/home/zym/sunmoon-registry-publisher-20260928-v1`（脚本、下载和索引缓存）纳入本次最终清理；当前未删。
本次只读 manifest 查询的临时解包目录已由 TemporaryDirectory 回收，没有留下新容器或卷。
系统 APT sources、dpkg 安装状态、系统共享库、Docker/Harbor/KIND 服务均未改动。
