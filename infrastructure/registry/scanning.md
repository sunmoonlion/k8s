# 扫描器与漏洞数据库维护

入口属于[外置Harbor](README.md)。数据库是扫描情报，存物料批次`databases/`，镜像在`images/`；归档schema、大小、SHA256、内文件和更新时间以[文件锁](../artifacts/files.lock.json)为准。

## 准备和实际检查

```sh
make -C infrastructure fetch-artifacts ARTIFACTS=trivy-db,trivy-java-db
make -C infrastructure check-artifacts ARTIFACTS=trivy-db,trivy-java-db
make -C infrastructure scanner-db-plan
make -C infrastructure scanner-db-install
make -C infrastructure scanner-db-verify
make -C infrastructure registry-scan-check
```

fetch有限重试并保留`.part`续传，完整大小/SHA验证后才进入正式文件。plan显示固定选择；install检查Docker所见数据盘，用scanner UID/GID10000在同文件系统临时目录解包、逐文件校验、原子安装缺失库；已有不同内容拒绝覆盖。verify离线核对数据库字节。

漏洞库schema2、Java索引schema1，前者判断漏洞，后者识别Java包。官方来源见锁；HTTPS校验保留，尚未加入发布者签名验证。安装临时目录只处理本次调用，不清仓库内容。

## Success代表什么

scan-check走真实Harbor API→jobservice→Trivy adapter，等待本次任务并取得报告。当前对象是固定HAProxy，不是所有应用发布门禁。检查库时间不能为未来且不得超过7天，这是本项目验收阈值。Trivy跳过在线更新，不能把过期快照长期当最新情报。

成功记录在`registry_instance_dir/scan-reports/`，root0600，含时间、镜像/扫描器、数据库身份、overview与明细。Success只证明链路完成；存在CVE时须按报告评估，不自动放行或生成自制系统包补丁。

## 失败与更新

- 库缺失/摘要不同：停止扫描，按锁核对来源；不覆盖运行库。
- 数据过旧：解析官方新manifest/归档及schema、审核并更新锁，再按维护方案换库、保留回退；当前自动定期更新、替换和旧库回退尚未实现。
- scan失败：查看jobservice/scanner限定日志与任务状态；healthy不替代真实扫描结果。
- 包漏洞：先核对运行进程是否加载/调用该包，再结合漏洞路径和官方修复评估。加载不等于可触达，未加载也不能无限期豁免。

已有扫描结论、运行库日期与已知包问题集中在[带日期验收](../../docs/platform-kind-v1/verification.md#仓库与扫描)。官方资料：[Trivy库](https://trivy.dev/docs/dev/configuration/db/)、[Harbor扫描](https://goharbor.io/docs/main/administration/vulnerability-scanning/)。实际版本以锁为准。
