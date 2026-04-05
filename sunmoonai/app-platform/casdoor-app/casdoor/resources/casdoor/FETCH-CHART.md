# 拉取 Casdoor 官方 Helm Chart

Chart 本体不提交到 git，部署前执行以下命令拉取到此目录：

```bash
helm repo add casdoor https://casdoor.github.io/casdoor-helm
helm repo update
helm pull casdoor/casdoor --untar --untardir "$(dirname "$0")/../"
```

执行后此目录下会出现 `Chart.yaml`、`values.yaml`、`templates/` 等文件。

## 查看可用版本

```bash
helm search repo casdoor/casdoor --versions
```

## 离线部署

如需离线环境，先在有网络的机器拉取后打包：

```bash
helm pull casdoor/casdoor --version 0.x.x
# 将 casdoor-0.x.x.tgz 传入集群节点，再 tar xzf 到此目录
```
