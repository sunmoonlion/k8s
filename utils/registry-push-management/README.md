# 镜像发布入口已统一

本目录脚本只转发到 `./sunmoon harbor publish --batch <绝对路径 JSON>`，默认只打印。
旧交互菜单、自动下载、目录扫描、节点加载回退和推送后清理已停用。
旧代码按摘要保存在 `legacy/local` / `legacy/cloud`，禁止直接运行。

日常参数、工具物料前置、凭据、实际执行与未完成边界见 [统一发布说明](../../sunmoonai/registry-platform/docs/publication.md)。
旧 `.conf` 当前不再由这些入口读取，保留待最终清点；不会自动转成新发布批次。
