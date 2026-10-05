# KIND声明入口与阶段依赖

环境来源在[infrastructure/environments/kind](../../../infrastructure/environments/kind/README.md)，当前Flux path为本目录；源码发布/晋级/退回方法唯一在[Flux维护](../../../infrastructure/flux/README.md)。本目录README不维护第二份当前digest。

## 文件职责

| 文件 | 责任 |
|---|---|
| kustomization.yaml | 根资源入口；递归组合其他声明 |
| namespace/foundation/registry-puller | platform-system引导基线与受限拉取密文 |
| release-info | 固定Git产物的发布标记 |
| services.yaml与模板 | 平台服务依赖；引用services/layout映射 |
| applications-各APP.yaml | 所选应用database→migration/Redis/Rabbit/identity→runtime/Web/Admin链 |

Flux Kustomization对象位于flux-system；其path指向组件，实际业务namespace来自环境变量/组件声明。目录名称不能派生新的namespace。

平台根服务先提供存储/数据库/入口，Casdoor db→init→runtime；ELK init→runtime→data-view/collector；RAGFlow database+storage→init→runtime；MongoDB服务与initialize配套。详细依赖以文件为准，维护先看哪个dependsOn未Ready，不只看根OCI对象。

## 变更与资源退出

stage只改选中模块/应用，审阅后提交发布并显式晋级。生成模板和已提交YAML各有职责，都保留；不手动改stage依赖绕过初始化检查。

当前阶段prune=false、deletionPolicy=Orphan，关闭配置/删引用不会自动停掉现有对象。退出阶段、暂停与停服务、删声明、数据回收分别处理；不可变Job输入须新代次。删除Completed Pod可能被仍在的Job/Flux重新生成；成功初始化记录不随意清理。

查看/故障用[cluster](../../../infrastructure/cluster/README.md)的指定kubeconfig与[Flux](../../../infrastructure/flux/README.md#故障与退回)。整群删除重建/数据恢复仍需单独实际验收。
