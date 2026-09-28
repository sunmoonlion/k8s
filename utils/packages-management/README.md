# 人工物料工具：保留能力与新版流程边界

本目录是人工工具，不以“有没有其他脚本调用”判断是否删除。当前保留三个原文件；本轮没有执行下载、安装、SSH、推送或清理。

| 文件/能力 | 处置 |
| --- | --- |
| `packages-management.sh` 的 deb 构建、自定义二进制打包、tar/chart 下载与菜单 | 保留人工能力。新版集群物料准备只覆盖锁定批次，没有完整替代任意 deb/chart 的交互处理 |
| 同脚本的远端安装、镜像导入/推送、清理 | 仍是旧实现；不能纳入新的正式安装路径。存在 SSH 校验关闭、口令参数及宽泛临时目录清理，尚待按能力拆分和适配 |
| `export-component-image-tars.sh` | 人工按组件清单导出 tar 并可选同步到节点；保留独立用途。当前按文件存在跳过、不验证摘要，产物不能直接视为已准入 OCI 发布物料 |
| `packages.conf` | 以上两个工具仍实际读取的配置，必须一起保留；本次未修改值、未复制凭据到其他模块 |

新版使用方法：

- 集群与平台正式物料：[物料准备手册](../../sunmoonai/kind-infrastructure/docs/物料提交备齐方案和方法.md)，批次位于既定 `packages-to-be-installed/releases/`。
- 发布工具与离线依赖：[发布工具物料](../../sunmoonai/registry-platform/docs/publisher-materials.md)。
- 镜像发布：`./sunmoon harbor publish --batch <绝对 JSON>`；tar 格式/摘要须先准入，不能从目录名猜可信版本。
- 空间回收：[获准回收清单](../../sunmoonai/kind-infrastructure/docs/wsl-space-reclamation-plan.md)，不执行旧工具附带的宽泛清理。

保留原代码不表示旧脚本所有能力都适用于新版集群。拆分前必须保全上述人工功能；以后有完整替代和使用核对后，再删除对应旧实现。云端新流程仍未经实机验证。
