# 待办 27 回传续：装 compose 后从第五节重跑

时间：2026-10-06 17:11。HEAD 上有 `145fe107`（装 compose 的修正）和 `2908f80b release(kind): 晋级到 b5b9658e`。工作区干净。`flux-source.yaml` 仍是 `revision: b5b9658eb717909e8b419eb593a834b92c6d7d45`，`digest: sha256:ba81d7d9eff670441811ad7ae06caf56533c54a43b7e66af33adf83408310e70`。

## 装 compose

`make -C infrastructure install-binaries BINARIES=compose` 退出 0（17:08:17，约 5 秒）。`infrastructure/.tools/bin/docker-compose` 在，32MB，模式 `0755`。没有走 `fetch-artifacts`。

## 五、部署

`platform-deploy OBJECT=all` 退出 2，52 秒（17:08:30–17:09:22）。日志 `infrastructure/.build/platform-deploy-20261006-170830.log`。compose 校验过了（`Require locked Compose` 为 ok）。随后失败任务：`Require a stop before changing an active listener`（`entry/service.yaml:184`）。原话：`Stop the owned entry before changing its configuration; existing listeners are never stopped implicitly.` 断言是 `entry_state.stdout != 'active' or not desired.changed`。`Preview desired configuration` 把 `haproxy.cfg` 标成 changed。最后一段 PLAY RECAP：`ok=12 changed=1 failed=1`。前面几段是 `failed=0`。

`sunmoon-entry.service` 仍是 active。`/etc/sunmoon/entry/haproxy.cfg` 的时间是 2026-10-05 11:16，这次没有改写它。

`flux-source-status` 退出 2。现网 `OCIRepository/platform` 的 spec 和 artifact 仍是 `sha256:e26d2a19…`，Ready=True。新包没有应用上去。

## 六、停下前的三条

- Kustomization 63 个，非 True 为 0。
- 非 Running/Completed 的 Pod 为 0。
- 四个应用列到的 Job 都是 Complete `1/1`（identity、database、redis、rabbitmq）。没有列出 migration Job。

`platform-check` 和八个 application-check 没有做。没有退回。

## 结论

不通过。compose 已装进本工位。部署停在入口：现网入口在跑，期望的 `haproxy.cfg` 与当前配置不同，部署链拒绝在不先停入口的情况下改它。现网声明包仍是旧摘要。
