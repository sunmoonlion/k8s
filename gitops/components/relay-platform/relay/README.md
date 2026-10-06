# Relay

边缘会合点：代理控制/数据流、沙箱流、工作台管理通道与 `/healthz`。独立 hostname、平台 CA、IngressRoute；无 NodePort。

镜像目前钉在 Harbor `app-images/relay` 的既有摘要（KIND v1-r3）。经应用构建链重建后改为 `platform/relay` 并更新 `image.lock.yaml`。管理口令在私有主备/SOPS，无密码表行。
