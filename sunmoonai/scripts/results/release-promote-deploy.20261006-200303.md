# 待办 27 回传续十：换 investment 的凭据密钥，发布晋级应用，再跑检查

时间：2026-10-06 20:03。没有退回。没有贴口令。

## 一、核对

头是 `0d32e8b2`，工作区干净。`investment-backend/config.yaml` 第 80 行是 `WORKBENCH_CREDENTIAL_KEY: {source: random, format: fernet}`。

## 二、作废旧密钥

执行删除时，主文件、备份和 `domain.sops.yaml` 都不在磁盘上。`sudo rm` 退出 1。`git rm` 退出 128，pathspec 没有匹配到工作区文件。索引里这份密文是已暂存删除。同目录的 identity、redis、rabbitmq、credentials、tls 都没有动。

## 三、重新暂存

`platform-stage OBJECT=app-platform/investment-app` 退出 0，70 秒。主备 `domain.yaml` 重新生成，都是 root、`0600`。新的 `domain.sops.yaml` 里 `ENC[` 有 5 处。workload 只改了四处 `config-sha256`。提交 `6bbac954`，消息 `deploy(investment): 凭据密钥换为 Fernet 格式（第 27 轮续十）`。

## 四、发布与晋级

`flux-release` 退出 0，26 秒。候选：

```yaml
digest: sha256:11bebe3959f7c5f1d4cd05697f11703df94dfd152d7e013962dc03f8e61b2474
path: ./clusters/kind
repository: oci://harbor.sunmoonai.com:30443/platform/deployments-kind
requires_sops: true
revision: 6bbac954c2189a13fab9ff749b940a9173e0c143
```

`revision` 等于当时的 HEAD。diff 只有 digest 和 revision。提交 `194ab597`，消息 `release(kind): 晋级到 6bbac954（0010 第 5 步，第四次）`。

## 五、应用源

`flux-source-apply` 退出 0，194 秒。`flux-source-status` 退出 0。`lastAppliedRevision` 是 `sha256:11bebe39…`。

investment 的四个新 Pod 都是 1/1 Running，年龄约 107 秒：

- `investment-api-74bc9d9dc7-mxq2r`
- `investment-worker-6c9dd9f44f-nlk2n`
- `investment-scheduler-55c949bf5d-cv2m7`
- `investment-runner-5df97d5876-22cmn`

## 六、检查

| 检查 | 退出 |
| --- | --- |
| platform-check OBJECT=all | 2 |
| application-check investment | 0 |
| application-check knowledge | 0 |
| application-check-public knowledge | 0 |

`platform-check` 失败任务 `Require Neo4j Browser acceptance`（`infrastructure/services/verify.yaml:270`）。断言 `neo4j_ui_acceptance.rc == 0` 不成立。fail_msg：`{"passed": false, "reason": "Browser HTML is unavailable"}`。RabbitMQ 管理台那一项这次是 passed。

## 结论

不通过。Fernet 密钥已换上并应用到现网，investment 四个进程是新 Pod，investment 和 knowledge 的检查都过了。`platform-check` 停在 Neo4j Browser 页面不可用。
