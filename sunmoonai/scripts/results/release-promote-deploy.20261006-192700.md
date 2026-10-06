# 待办 27 回传续九：只重跑检查

时间：2026-10-06 19:27。头是 `174c987f`，工作区干净。没有重新部署，没有退回。

## 检查

三个都不是 0。

`platform-check OBJECT=all` 退出 2，72 秒。失败任务 `Verify RabbitMQ management TLS, login page and authenticated API`（`infrastructure/services/verify.yaml:245`）。解析检查输入时：`object of type 'dict' has no attribute 'rabbitmq_username'`。结果 JSON 被 `no_log` 藏住了。

`application-check APP=knowledge` 退出 2，37 秒。`application-check-public APP=knowledge` 退出 2，34 秒。失败任务都是 `Require actual domain integration acceptance and exact cleanup`（`infrastructure/applications/verify.yaml:492`）。断言 `provider_check.rc == 0` 不成立，fail_msg：`Knowledge integration failed; inspect private evidence, do not infer success from ready Pods.`

诊断文件 `infrastructure/.build/models/knowledge-domain-last.json`：`rc` 是 1。stderr 一共 7 行：

```
Traceback (most recent call last):
  File ".../knowledge-backend/provider/verify.py", line 85, in <module>
    result['checks'].update(execute('investment-api',(root/'verify-investment-http.py').read_text(),records,120)['http_checks'])
  File ".../knowledge-backend/provider/verify.py", line 31, in execute
    raise RuntimeError('Invalid '+app+' verifier response; rc='+str(out.returncode)+'; error_class='+(errors[-1] if errors else 'unavailable')) from None
RuntimeError: Invalid investment-api verifier response; rc=1; error_class=ModuleNotFoundError
```

## 结论

不通过。第 5、6 步还没闭合。`platform-check` 卡在 RabbitMQ 管理界面的检查输入缺少 `rabbitmq_username`。knowledge 的领域检查调用 investment-api 校验器时得到 `ModuleNotFoundError`。
