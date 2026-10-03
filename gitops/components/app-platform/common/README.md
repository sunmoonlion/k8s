# 应用共用部署机制

本目录保存四应用共用的数据库、Redis、RabbitMQ、Casdoor身份及API/Worker/Scheduler和前端声明模板。原生infrastructure/applications/deploy.yaml直接渲染本目录；不经过tpl应用，不复制部署脚本。

每个应用的开关、后端配置、Web/Admin配置、镜像锁、生成声明与说明仍在相应app/组件目录。模板只引用传入配置；用户名、域名、schema和镜像不在此复写。秘密保留在私有输入和SOPS中。平台共享namespace与版本仍来自环境及物料锁。

Python初始化/验收脚本为.py.j2，应用名渲染后嵌入对应ConfigMap。对于tpl，渲染须保持既有Job内容不变，避免改变不可变Job；新增应用独立对象和账号，不借用tpl身份。所有组件仍由同一Make/Ansible/Flux入口部署。
