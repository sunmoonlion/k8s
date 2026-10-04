# 集群内 HTTPS 服务路由

`config.yaml` 是用户配置真源，域名从环境命名空间派生。原生 services-stage/bootstrap 渲染到本目录。ExternalName 只解析到 Traefik Service，TLS保留集群内DNS名/SNI/CA验证；不固定ClusterIP、不绕行宿主机代理、不关闭证书检查。Knowledge路由只暴露现有 `/api/internal/v1/knowledge`，Casdoor保留公开issuer，通过Host一致的HTTPS回通道取得令牌和公钥。

证书私钥只给Traefik TLS Secret；消费者仅持公开CA。身份在 `/etc/sunmoon/services/sunmoon-kind/service-access/tls`，独立恢复副本在数据盘同责任路径，缺失时恢复，不重生成已声明身份。与公开Casdoor/应用证书分开，不改变30443入口路由。证书为既定五年，本机单区域开发配置不代表云端HA。

后端引用Service的http命名端口，Knowledge实际端口仍由其后端config.yaml/api_port唯一决定；路由不再复制8000常量。ExternalName的客户端HTTPS端口仍为Traefik服务443。
