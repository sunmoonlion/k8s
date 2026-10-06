# Casdoor：身份服务维护

代码归app-platform/auth-app，database Job在data_namespace，init/runtime在app_namespace。内部服务HTTP8000，公共HTTPS由Traefik/宿主SNI入口提供；组件config维护域名、数据库名/角色和文件卷。

## 输入和初始化

services_config_dir/credentials.yaml保存casdoor_db_password、casdoor_admin_password；引导用户固定built-in/admin。casdoor_application_secret是预留平台输入，不是各应用Web/Admin的client_secret，应用私有身份由自身Job管理。

独立database Job初始化库/角色，init隔离服务导入身份并写/files/.initialized-v1；runtime不重复导入。marker存在时仅做不覆盖身份的检查；Casdoor官方服务仍有内置schema行为，不宣称与业务独立迁移完全相同。

## 恢复与检查

备份同时覆盖PostgreSQL中的Casdoor数据库/角色、Casdoor文件卷和初始化marker、私有口令/TLS。单独恢复marker会错误跳过需要的初始化；单独重建空文件卷又可能重置身份。

services-check核可信TLS admin登录和实际session；各应用check另外核Web/Admin PKCE/SSR/CSRF及关系服务token。登录通过不能推导所有业务授权完成。修改初始口令文件不会更新远端账号，目录/domain/账号变更须完整身份迁移和证书/回调联动。

## 配置字段

当前值以[config.yaml](config.yaml)为准，手册维护字段职责，不再复制一套默认值。

| 字段 | 类型 | 维护条件 |
|---|---|---|
| `services_casdoor_enabled` | 开关 | 部署/渲染准入；不代替停止、卸载或删除数据。 |
| `casdoor_volume.name` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `casdoor_volume.node` | 文本/表达式 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `casdoor_volume.size` | 文本/表达式 | PV声明容量；不构成ext4目录硬配额，不自动扩盘。 |
| `casdoor_volume.uid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `casdoor_volume.gid` | 整数 | 存储/持久身份；已有数据不能通过普通配置编辑迁移。 |
| `casdoor_hostname` | 文本/表达式 | 与客户端、TLS、入口/Service及网络策略联动；既有节点端口映射不能热改。 |
| `casdoor_database` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |
| `casdoor_database_user` | 文本/表达式 | 账号名或业务边界；已有远端身份/数据须显式核对，禁止静默认领/迁移。 |

## 部署、检查与退回

共同平台操作走[services维护](../../../../../infrastructure/services/README.md)的候选→审阅→stage/提交→发布晋级→bootstrap/check；组件没有另一套部署入口。版本/摘要取[物料锁](../../../../../infrastructure/artifacts/README.md)，运行namespace取共享site。关闭开关不会自动停服或清数据。

配置、身份或卷不符时保留现场；退回固定源的方法见[Flux维护](../../../../../infrastructure/flux/README.md)，schema/账号/持久数据不随Git自动回滚。日期结果与未覆盖范围在[验收边界](../../../../../docs/platform-kind-v1/verification.md)。
