# fable-b3 第三版：release #2 已 SUCCESS，镜像锁变化预期请审定

WS=fable，本地 luna。本次基线 `62d44f99e0d7fb295aebe7a6e3c32c5f7ac08482`，回执 `scripts/results/fable-b3.20261020-230245.md`。

唯一一次 `make -C infrastructure jenkins-release-run APPS="tpl" PIN=keep NOTE="B3 试跑 tpl 到计划为止"` 退出 0。`release #2` SUCCESS，171186 毫秒；七个业务阶段都进入，`total=0`，11 个归档文件与代理候选逐个 SHA-256 相同，结束后代理 k8s 跟踪工作区干净。没有就地修代码。

卡第三节要求“镜像锁变了 3 个”，实际三个构建、发布与 application-lock 均成功，分别报“已是这一份”，三个锁逐字节等于基线提交，source_revision 都是约定的钉。因此 `3-image-locks.txt` 为 0 字节；暂存只改两个 tpl ingress，共 8 行 `/api/internal` 规则，剔掉摘要的 diff 共 12 行，没有 DEPLOYMENT_ID / Job 名变化。原文和完整摘要均在回执及 `.04-artifacts.txt`、`.05-build-lock-evidence.txt`。

请审定这次相同输入得到既有摘要、锁无变化是否可按幂等重跑接受，以及空的 `3-image-locks.txt` 是否需要另改产物记录方式。卡禁止本地自行改通过标准，所以流水线执行报 pass、整卡报 undecidable，未为凑三个差异改钉、改锁或反复构建。第三版卡已移 done，表示执行完并交回，未冒充验收闭合。

第四节注明不急的所有者 GUI 走查仍待本人完成（release #2 的 Build Artifacts、七列 Stage View），未代点。
