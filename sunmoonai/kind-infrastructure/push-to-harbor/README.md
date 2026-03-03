# 推送镜像到 Harbor（push-images-to-harbor）

将镜像或 tar 推送到 Harbor，与 **load-kind-images**、**build-kind-node-image** 一致，支持两种来源：

- **镜像列表文件**：`DEFAULT_IMAGE_FILES` 或 `--img-file`，一行一个镜像名，脚本 `docker pull` 后打 tag 并 push。
- **tar 目录**：`DEFAULT_TAR_DIR` 或 `--tar-dir`，对每个 `.tar` 执行 `docker load`，解析出镜像名后打 tag 为 `HARBOR_HOST/HARBOR_PROJECT/<repo>:<tag>` 并 push。

与 **load-images** 平级，同属 `kind-infrastructure/`。

## 目录

| 文件/目录 | 说明 |
|-----------|------|
| `push-images-to-harbor.sh` | 主脚本 |
| `push-images-to-harbor.conf` | 默认配置（Harbor 地址、项目、镜像列表、tar 目录） |
| `tar-default-dir/` | **默认 tar 目录**：将需要推送的 `.tar` 放入此目录；无参时与 conf 中 `DEFAULT_TAR_DIR` 一致 |

## 行为

- **无参数**：使用 conf 中 `HARBOR_HOST`、`HARBOR_PROJECT`、`DEFAULT_IMAGE_FILES`、`DEFAULT_TAR_DIR`（相对路径相对本目录）。
- **指定 `--img-file` 或 `--tar-dir`**：仅使用本次指定的内容（可逗号分隔多个文件/目录），不再读 conf 默认。

## 用法

```bash
# 使用前先登录
docker login harbor.sunmoonai.com:30443

# 无参数：使用 conf 默认（镜像列表 + tar 目录）
./push-images-to-harbor.sh

# 仅镜像列表（一行一个镜像名，# 注释）
./push-images-to-harbor.sh --img-file ./images-default.txt
./push-images-to-harbor.sh --img-file ./a.txt,./b.txt

# 仅 tar 目录（可多个，逗号分隔）
./push-images-to-harbor.sh --tar-dir ./tar-default-dir
./push-images-to-harbor.sh --tar-dir /path/to/images,/another/dir

# 仅打印不推送
DRY_RUN=1 ./push-images-to-harbor.sh
```

## 配置（push-images-to-harbor.conf）

- `HARBOR_HOST`、`HARBOR_PROJECT`：Harbor 地址与项目。
- `DEFAULT_IMAGE_FILES`：默认镜像列表文件，多个用空格分隔，相对路径为相对本目录；留空则不用。
- `DEFAULT_TAR_DIR`：默认 tar 目录，相对路径为相对本目录（默认 `tar-default-dir`）。
