# B2c：代理已上线，手动 render-check 提交 HTTP 400

WS=fable，执行 a686ce59。第二节已过：保留七父仓，18 子仓全部检出成功，无 alternates；.venv 和工具安装成功；代理 active/enabled、User=zymun、WantedBy=sunmoon-platform.target；节点在线的 API 检查及 status 通过。物料、控制器、仓与代理安装均不必盲目重做。

第三节 `make -C infrastructure jenkins-agent-check` exit=2，停在 `agent.yaml:250` 的 `Queue a forced render-check build`，HTTP 400，预期 201；前面的节点在线与 CSRF crumb 获取都通过。保留 no_log，没有抄 crumb/cookie/口令，没有重发 POST。当前第 252 行以查询参数传 BRANCH/APPS/FORCE、未带表单 body，供定位；400 服务端原因尚未确定，请修后给第三节接续卡。

另有独立事实：已有定时构建 #1–#5，在代理上线后 #1 已开始跑 a686ce59 的渲染。19:19 元数据均无终态；不能当作这次手动提交成功，也未据此判 B2 通过。请接续时核对自动 #1 的最终结果、私有身份生成/恢复记录及产物。原生日志 `/mnt/sunmoon-data/jenkins/home/jobs/render-check/builds/1/log`；本机 `.build/jenkins/timer-render-check-1.20261020-192026.snapshot.log` 为 19:20:42 运行中快照，0600，不进 Git。

第四节边缘与 platform-status、第五节所有者走查未执行。控制器、代理保持 active/enabled，入口 Jenkins 与 Harbor 均 200。卡已归档仅表示本轮交回，B2 未通过。

[完整回执与十份原始输出](../../../../../scripts/results/fable-b2c.20261020-191232.md)。04 含本地把 @tmp 计入仓数的失败检查；05 已修正按实际 Git 仓核对，不改通过标准，原失败日志保留。10 为 19:22:22 最新只读状态，#1 仍在运行、无终态。
