# Cursor 发布卡：集群侧 frpc

这是发布执行卡，先供 Fable 审阅。**收到 Fable 审阅通过且所有者通知 Cursor 后再执行。**
只在 luna 工作树。本地提交结果，不 push、不合并 fable。不改应用 origin、回调、IngressRoute，不改 `WORKBENCH_TRUSTED_PROXY_CIDRS`，不重新生成 `edge-frp.yaml`。

```text
被测仓：k8s，~/worktrees/luna/k8s
跑：按下面「发布」顺序执行；镜像中转失败或 compressed_layer_bytes 仍缺则立即停，不晋级
仓与提交：k8s 父提交 3ab76558；执行时 HEAD 须含平台清单 sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191
预计：40–70 分钟；要联网、Docker/KIND、Harbor、Flux；不需要 Windows
看什么：frpc 镜像进入 Harbor platform/frpc，摘要为 sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191；两个 frpc Pod Running；frps 上 investment、casdoor、relay 各有两个成员；不在所有者 hosts 里的网络打开 https://investment.sunmoonai.com:30443 出现登录页
前提：所有者已把本机 /etc/sunmoon/services/sunmoon-kind/edge-frp.yaml 拷到边缘，远程已确认 frps 换的是这一份令牌。未确认则不要开始
回传：k8s/sunmoonai/scripts/results/frpc-release-cursor.<时间>.md；记录每步退出码、镜像摘要、Pod 名与 imageID、Flux revision/digest/Ready、frps 日志里看到的组成员、登录页结果。最后一行 exit=<码>。结果只本地提交
```

## 镜像锁

`compressed_layer_bytes` 发布链要用：`artifacts/publish.yaml` 的 skopeo 临时盘大小，以及 `tasks/publish-image.yaml` 在准备归档和目标标签还不存在时的容量预算，都会读它。没有这个正整数，`services-materials` / `services-publish` 不能跑。

Harbor 与 Pod imageID 使用的摘要是 linux/amd64 平台清单 `sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191`。`sha256:99ece6a2…` 是同一镜像的多架构索引，只记在锁的 `selection_note`，不作为集群拉取摘要。

锁里必须有 `config_digest` `sha256:33f4aecae1ecfa322004e3d88fcacf10538fe65b57ab94db1b196c0495c94c89` 和 `compressed_layer_bytes` `10463177`。缺了就停，不要编。

## 发布

1. 核工作区干净、HEAD 含平台清单 `8dd029fa…`、集群是 `kind-sunmoon-kind`、容量不低于 10 GiB、SOPS 主备身份都在。保存本次原 `infrastructure/environments/kind/flux-source.yaml`，不要覆盖更早的回退材料。前提里的令牌交接未确认则停。发布前用 `skopeo inspect --raw docker://docker.io/fatedier/frpc@sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191` 核对原始清单的 sha256，取不到就停。
2. 只中转 frpc，不发布其它镜像：

```bash
make -C infrastructure services-materials SERVICE_IMAGES=frpc
make -C infrastructure services-publish SERVICE_IMAGES=frpc
```

Harbor 上 `platform/frpc` 的摘要必须是 `sha256:8dd029fa1f995629d6f31157f270633224f39492da079b099ce39dddaad3e191`。
3. 再跑一次 stage，确认声明不再变化，且没有重写私有输入：

```bash
make -C infrastructure platform-stage OBJECT=ingress-platform/frpc
```

4. 审 diff。通过后本地提交，再：

```bash
make -C infrastructure flux-release
```

5. 对照 `infrastructure/.build/flux/source-candidate.yaml` 的 repository、digest、revision、path、requires_sops。把候选原样写入 `infrastructure/environments/kind/flux-source.yaml`，不要把 revision 改成晋级提交。本地提交晋级，然后：

```bash
make -C infrastructure flux-source-apply
make -C infrastructure flux-source-status
```

6. 看 `ingress-platform-dev` 里两个 frpc Pod 都是 Running，imageID 带上面的摘要。通用 `platform-check` 的镜像清单里没有 frpc，不能用它代替这一看。

## 验收

- 两个 frpc Pod Running。
- 边缘 frps 日志里，`investment`、`casdoor`、`relay` 三个组各有两个成员。`loginFailExit` 仍是 false；对不上令牌或 frps 未换令牌时会一直重连，这不算通过。
- 用手机流量打开 `https://investment.sunmoonai.com:30443`，出现登录页。所有者机器 hosts 里的访问不算。

登录之后的聊天、Windows 代理安装不在这张卡里。
