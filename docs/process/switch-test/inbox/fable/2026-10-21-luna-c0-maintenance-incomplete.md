# C0 回执：离线压缩未执行，服务恢复但全量 Flux 验收失败

WS=fable，luna 交远程 Fable。C0 保留在 inbox/luna，没有移动到 done。

详细回执：`scripts/results/fable-c0.20261021-1112.maintenance.md`；准备提交 `ecb24a3d3` 的 ISO/校验结果保留。

1. 所有者已批停机；原生 stop 和两块 ext4 的 fstrim 成功。WSL shutdown 后 VS Code 子进程在离线期间重新启动 WSL，DiskPart 没有调用。最初离线异常被 finally 中恢复失败覆盖，下一版一次性维护材料需先记录原异常；重新离线前需关闭 VS Code/终端的 WSL 自动连接，从 Windows 独立启动。本轮不再重跑。
2. 现有业务已恢复：三节点 Ready，286 Pod 中非 Succeeded 的 not_ready=0；Harbor 200、Knowbench 307、Jenkins login 200；附盘任务已恢复启用且成功，维护标记已移除。但原生 platform-start 的全量 Flux 检查在 11:11:58 超时失败，worker exit=1。
3. 105 个 Flux 对象中 10 个旧 investment-* 不 Ready，仍指旧目录：investment-admin、investment-agent-releases、investment-database、investment-identity、investment-migration、investment-rabbitmq、investment-redis、investment-runtime、investment-service-identity、investment-web（都在 flux-system，sourceRef=OCIRepository/platform）。请核定遗留对象的处置清单并发卡；本地没有删它们或改 guard，不能靠放宽判据写成恢复通过。
4. 观察到 C 空闲只增加 223,522,816 字节（0.208 GiB）；系统 VHDX 长度不变，数据 VHDX 长度减少 224 MiB。未完成离线 compact，不报成已回收约 180 GiB。VMware 尚未建机，卡的“先压缩后建机”尚未满足。

请看回执和原始失败输出后给下一步；本轮不改变 C0 规格、形状或停点。
