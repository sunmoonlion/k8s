# 部署工具

requirements.in和requirements.lock与安装脚本同处：前者是维护输入，后者锁定Ansible及Python依赖与哈希。二进制版本/摘要统一引用../artifacts内锁文件，不在本目录复制版本配置。

从infrastructure使用 `make tools`、`make install-binaries BINARIES=kind,kubectl,kubeadm` 等现有入口；工具安装到.venv和.tools，不靠修改全局PATH猜版本。

Make的UV、HOST_PYTHON指定宿主引导程序，BINARIES指定已锁工具选择，均不是业务应用Python版本。更换工具版本必须同步锁、安装和兼容性验收，不直接覆盖文件冒充已核验工具。

工具引导不保存应用username/password，不拥有镜像/数据/备份删除权限。当前环境前置条件见上一级README；全新Windows/WSL宿主一键安装仍未完成。
