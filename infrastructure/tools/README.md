# 工具安装与依赖维护

工具在本工作树`.venv/`、`.tools/bin/`和版本目录中隔离，服务运行工具另复制到其`/opt/sunmoon/...`目录。宿主Python用于Ansible/校验，不与应用容器Python runtime混为同一版本。

## 安装前提与入口

需要宿主已有uv、Python、jq及Docker/systemd等[宿主前提](../README.md#运行前提)。全新宿主安装链尚未交付，`tools`当前从官方PyPI在线同步哈希锁，不自动复用应用的国内/代理fallback。

```sh
make -C infrastructure tools
make -C infrastructure install-binaries BINARIES=kind,kubectl,kubeadm
make -C infrastructure install-flux
make -C infrastructure install-secrets-tools
make -C infrastructure services-tools
```

安装二进制前按[artifacts](../artifacts/README.md)备齐选中锁文件。Ansible先完整校验源/目标目录和文件，不允许链接或字节漂移；只复制受支持文件到工作树工具目录，核验安装内容/版本，保持全局命令不作为无条件替代。

## 来源、失败和升级

[requirements.in](requirements.in)声明入口，[requirements.lock](requirements.lock)固定全部包/hash，`UV`与`HOST_PYTHON`取Make参数。age/Helm等归档须验证成员而不盲解压。工具包缺失先恢复锁内物料，网络问题保留校验后处理代理，禁止临时解除require-hashes。

升级先更新固定物料/依赖锁，审核使用方兼容性和源码边界，保留回退字节后验证。当前没有自动升级/全局Python替换入口。SOPS/age恢复约束见[secrets](../flux/secrets.md)。

## 原始旧 KIND 的工具

原始旧kind保留的kubectl在`/home/zymun/packages-to-be-installed/legacy/kind/kubectl-1.27.3-existing-kind-linux-amd64/bin/kubectl`；相邻provenance.json记录从原节点取得的版本和摘要。它不属于新体系物料批次，不安装到全局PATH。新sunmoon-kind日常使用本工作树`infrastructure/.tools/bin/kubectl`，版本以artifacts文件锁为准。
