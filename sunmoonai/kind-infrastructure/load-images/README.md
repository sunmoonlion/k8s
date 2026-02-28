# Kind 镜像加载（load-kind-images）

将镜像或镜像 tar 包加载到 Kind 集群所有节点，供本地部署（如 Harbor、Traefik）使用。

## 目录与配置

| 文件/目录 | 说明 |
|-----------|------|
| `load-kind-images.sh` | 加载镜像到 Kind 的主脚本 |
| `load-kind-images.conf` | 默认配置（镜像列表文件、tar 目录、可选集群名） |
| `images-default.txt` | 默认镜像列表（一行一个镜像名，`#` 为注释） |
| `tar-default-dir/` | **默认 tar 目录**：把需要加载的 `.tar` 文件复制到此目录即可 |

## 行为说明

- **镜像**：宿主机 `docker pull` 后 `kind load`（失败时用 docker save + 各节点 ctr import 兜底）。
- **tar**：仅通过**目录**指定；脚本会加载目录内全部 `.tar` 到集群各节点。
- **默认与参数**：
  - **无参数**：使用 conf 中的 `DEFAULT_IMAGE_FILES`（镜像列表文件）和 `DEFAULT_TAR_DIR`（tar 目录，如 `tar-default-dir`）。
  - **指定任意参数后**：只使用本次指定的内容，**不再**读取 conf 默认（既不读默认镜像列表，也不读默认 tar 目录）。

## 用法

```bash
# 无参数：使用 conf 默认（images-default.txt + tar-default-dir/ 下全部 .tar）
./load-kind-images.sh

# 仅指定镜像列表文件（可多个）
./load-kind-images.sh --img-file images-default.txt
./load-kind-images.sh --img-file list1.txt,list2.txt

# 仅指定 tar 目录（可多个），加载该目录内所有 .tar
./load-kind-images.sh --tar-dir ./tar-default-dir
./load-kind-images.sh --tar-dir /path/to/packages-to-be-installed/images,/another/tar-dir


# 组合：指定镜像列表 + 指定 tar 目录
./load-kind-images.sh --img-file my-images.txt --tar-dir ./tar-default-dir

# 帮助
./load-kind-images.sh --help
```

## 配置项（load-kind-images.conf）

```bash
# 默认镜像列表文件（相对本目录或绝对路径，多个用空格分隔）
DEFAULT_IMAGE_FILES="images-default.txt"

# 默认 tar 目录：该目录内所有 .tar 会被加载；相对路径为相对本目录
DEFAULT_TAR_DIR="tar-default-dir"

# 可选：Kind 集群名，留空则从 k8s-admin.conf [KIND] 读取
# KIND_CLUSTER_NAME=kind
```

## 常见用法

1. **一键加载默认镜像 + 自备 tar**  
   把 `packages-to-be-installed/images/*.tar` 复制到 `tar-default-dir/`，然后执行：
   ```bash
   ./load-kind-images.sh
   ```

2. **只加载某目录的 tar，不用 conf 默认**  
   ```bash
   ./load-kind-images.sh --tar-dir /path/to/my-tars
   ```

3. **只加载某镜像列表，不用 conf 默认**  
   ```bash
   ./load-kind-images.sh --img-file my-list.txt
   ```

## 上层调用

- `deploy-kind.sh` 步骤 5/6 会调用本脚本（无参，即使用 conf 默认）。
- 兼容包装：`../load-initial-images-kind.sh` 会转发到本脚本，`--file` 会转为 `--img-file`；`--tar` 已废弃，请改用 `tar-default-dir/` 或 `--tar-dir`。

推送镜像到 Harbor 的脚本与 load-images 平级，位于 **`../push-to-harbor/`**，用法见该目录下 README.md。
