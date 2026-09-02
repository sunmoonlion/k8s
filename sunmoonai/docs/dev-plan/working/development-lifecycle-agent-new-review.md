# `development-lifecycle-agent-new.md` 候选对照评审

> 评审日期：2026-09-02
>
> 评审者：Luna
>
> 结论：**选择 Luna 候选作为本轮最优方案。**Cursor 候选保留为 Git/worktree 场景化
> 表达的改进来源；Qwen 候选保留为归属三律和写前检查的改进来源；Kimi 候选保留为
> 简洁结构和“临时规范必须代码化”提醒的来源。
>
> 利益冲突声明：评审者同时是 Luna 候选作者，因此这不是独立终审。本文给出可复核的
> 比较依据和固定 hash；后续 integrator 或人可推翻本结论，但必须指出具体标准与证据。
>
> **候选集修正：**第一版评审只按精确文件名 `development-lifecycle-agent-new.md` 枚举，
> 漏掉了后缀为 `-qwen3.8.md`、且在首次枚举后才完成写入的 Qwen 候选。旧的三候选评分
> 因集合不完整而作废；本文已按四候选重新评审。不能用旧 review hash 作为当前结论。

## 1. 评审对象

评审开始后不修改其他 worktree 的候选。对象按内容 hash 冻结：

| ID | source worktree | 行数 | 字节 | SHA-256 |
| --- | --- | ---: | ---: | --- |
| Cursor | `cursor/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new.md` | 756 | 50,903 | `6abd9707d2b88ab57b0bd72df63432cedff161d6b49b12e4e620930a2b274e96` |
| Kimi | `kimi/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new.md` | 609 | 35,935 | `b4d78814b31a24daa97fb967af206d8d5b33a1c5b29ec2909b0c3ac2f975905b` |
| Qwen | `qwen3.8/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new-qwen3.8.md` | 728 | 44,605 | `f888dd676e1e0fb61758b0fbfb4f74fb22ef68966e55143e02878ed66a4a9370` |
| Luna | `luna/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent-new.md` | 908 | 45,485 | `6cdcfb85dc0d21f8489cf806d25577590857d1eb33b611b63359a54d03bb3b44` |

Opus worktree 在重新取证时没有匹配候选，不进入本轮比较。master 不是候选来源或投稿位置。

## 2. 本轮硬要求

候选必须同时满足：

1. Agent 路径从前端 Submission 开始，经 FastAPI 受理、整理并冻结 Task；
2. 复杂 Task 的 sandbox/Git 工作仓由 FastAPI 后端直接或通过 provisioner 供给；
3. Human 路径由人建立 Git 仓库和 worktree；
4. Agent supervisor 与 Human supervisor 的协调地位等同；
5. 文档可独立阅读，不把共同执行内核留给将来可能删除的另一份文档；
6. 多执行者产出不得落在同一物理可写路径；文档与未跟踪文件也不例外；
7. commit、branch、worktree、Artifact、共享路径和外部副作用必须区别处置；
8. 覆盖、迟到、失败、取消、恢复、整合、发布与清理均有安全规则；
9. 候选不能直接抢占 `master/main` 或最终发布路径；最终发布有唯一 integrator；
10. 不得用可能删除他人或用户未提交成果的动作“修复”覆盖事故。

违反第 1—5 项属于模型偏离；违反第 6—10 项属于本轮事故暴露出的安全缺口。

## 3. 评分方法

评分用于呈现判断，不代替硬门禁。总分 100：

| 维度 | 权重 | 判定重点 |
| --- | ---: | --- |
| 生命周期模型对齐 | 20 | 前端→FastAPI→Task→workspace→Agent→Delivery；Human 对照准确 |
| 所有权与隔离 | 25 | owner、branch/worktree、同名产出、共享工作树和用户改动 |
| 场景覆盖 | 20 | Git/非 Git、多仓、CI、大文件、敏感物、外部副作用、重试和迟到 |
| 发布、恢复与清理安全 | 20 | integrator、冻结、CAS、事故保全、可达性和垃圾回收 |
| 一致性与可维护性 | 15 | 自足、链接有效、无危险矛盾、结构和篇幅 |

同分时优先选择能够阻止不可恢复数据丢失和静默覆盖的候选。

## 4. 总分

| 候选 | 模型 20 | 隔离 25 | 场景 20 | 发布/恢复 20 | 一致性 15 | 总分 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Luna** | **20** | **25** | **20** | **20** | 12 | **97** |
| Cursor | 18 | 22 | 18 | 13 | 10 | 81 |
| Qwen | 19 | 20 | 16 | 11 | 10 | 76 |
| Kimi | 13 | 16 | 12 | 11 | 12 | 64 |

分数不是“作者投票”。下面逐条列出拉开分差的文本证据。

## 5. Cursor 候选

### 5.1 成立之处

- L74 明确 FastAPI 是工作仓供给方而不是 supervisor，符合入口边界；
- L96 明确 Agent/Human 都只写自己的 worktree 和命名分支；
- L103—L104 直接总结本次“共享 checkout 后写覆盖先写”的事故；
- L543—L557 清楚区分未提交文件、commit、branch 和共享主线；
- L575 起的 S1—S27 场景表最贴近日常 Git 操作，尤其覆盖 amend、force-push、submodule、
  sandbox 回收、handoff 单写者和跨会话接手；
- L564—L565 的“人的主 checkout 不是投稿箱”是三稿中最直接的操作口令。

### 5.2 阻断与缺口

1. **事故处置含危险删除。**L581 的 S1 要求移动自己的稿后“删掉共享路径上的那份”。当
   共享路径已经被其他执行者覆盖时，当前内容未必属于本执行者；直接删除可能造成第二次
   数据损失。这与“来源不明先保全”冲突，违反硬要求 10。
2. **发布竞争未闭环。**候选强调 integrator/worktree，但没有要求更新远端 ref、最终文件或
   对象存储时校验预期 HEAD/version。两个 integrator 或目标漂移时仍可能 lost update。
3. **载体覆盖不足。**“四种载体”主要围绕 Git；CI 并行输出、内容寻址大文件、敏感 Artifact、
   共享缓存、对象存储键和数据库/发布副作用未形成统一分类。
4. **存在失效链接。**`../../working/collaboration.md` 与
   `../../working/doc-conventions.md` 在该 worktree 中不存在，降低文档可执行性。
5. **事故归因写得过早。**L729 将覆盖实例直接归因到具体助手。在没有完整工具事件和原始
   未提交版本的情况下，能够证明共享路径发生覆盖，不足以仅凭最后 hash 完整证明写入顺序。

### 5.3 可吸收内容

后续整合可吸收 Cursor 的四问写前检查、主 checkout 不是投稿箱、S2/S3/S8/S9/S14/S20/S27
等高频 Git 场景，但必须把 S1 改为“停写、保全、分流、溯源”，不能删除来源不明文件。

## 6. Kimi 候选

### 6.1 成立之处

- 全文最短，层次清楚；
- L437—L487 已包含产出物归属、自己的 branch/worktree、候选整合、rebase/amend/force-push
  和 sandbox 销毁后的可重建要求；
- L467—L477 的覆盖恢复遵循先保全、恢复分支、判定关系、再留痕，方向正确；
- L590—L592 指出临时 Agent 文档删除前，长期纪律必须进入代码、测试或门禁，这是重要的
  生效边界提醒。

### 6.2 阻断与缺口

1. **建仓主体偏离冻结模型。**L7、L89、L102 均写“复杂任务由 agent 在 sandbox 中构建
   Git 仓库”。本轮约定是 FastAPI 后端根据 Task 供给 sandbox/Git 和任务材料，Agent 接收
   已物化工作区；这是硬要求 2 的直接偏离。
2. **同名产出与共享路径规则过于概括。**虽然要求一执行者一分支一 worktree，但没有明确
   “用户指定最终文件名是 publication target，不是候选写入路径”，也没有共享物理目录下
   owner namespace 的降级协议。
3. **非 Git 场景不足。**没有系统覆盖 CI 输出、共享缓存、内容寻址大文件、敏感 Artifact、
   对象存储 CAS 和无 Git 多 Attempt 的键隔离。
4. **发布阶段缺少条件更新。**没有预期 HEAD/version、non-fast-forward、PR 审后新增 commit
   和发布幂等回执的规则。
5. **commit 保留语义不够精确。**提出从 reflog 恢复，但没有把 reflog 与持久可达 ref 明确
   分开；reflog 只能事故抢救，不能成为保留策略。

### 6.3 可吸收内容

后续 Human 文档可吸收 Kimi 对“临时规则最终必须代码化”的总结，以及更紧凑的产品 Task 与
开发执行边界表达。

## 7. Qwen 候选

### 7.1 成立之处

- L70—L122 对 Agent/Human 两条路径作了清楚对照；L104、L112 明确 Agent 侧由平台
  （FastAPI/sandbox 基础设施）建立工作仓，Human 侧由人建立，supervisor 地位等同；
- L527—L538 的“单一写入面、自己的 branch/worktree、候选命名”把归属放在写入之前；
- L540—L550 的五项写前检查很实用，尤其要求先判断路径归属、当前 worktree 和目标是否
  已有他人产物；
- L553—L593 分执行者/产出物、生命周期阶段和冲突风险三层处理，结构比单一长表更易读；
- L595—L608 正确区分 commit 与分支运输，并要求清理前 commit 可达；
- 它实际把自己的文件写入 qwen3.8 worktree，没有写 master，也因此在其他同名稿发生冲突
  时保住了独立候选。

### 7.2 阻断与缺口

1. **把文件后缀误当成普遍隔离机制。**L535—L538、L563 要求并行文档必须使用
   `<主题>-new-<assistant>.md`。真正的候选隔离单位应是 branch/worktree；不同分支可以且通常
   应该修改同一相对路径，便于对同一目标做 diff 和选择。助手后缀仅适用于多个候选确实要
   同时发布到同一树的场景，不能替代 worktree。
2. **事故归因证据不足。**L20、L515、L680 等直接写“Luna 覆盖 Cursor”。现有可证明事实是
   多执行者曾向共享路径写入、候选内容发生替换；若没有完整工具事件和被覆盖前 hash，不能
   仅凭最后文件完整证明覆盖顺序和责任人。
3. **缺少条件式发布。**没有要求 integrator 更新远端 ref、最终文件或对象存储时核对预期
   HEAD/version；独立候选安全不代表最终发布无 lost update。
4. **非 Git 产出覆盖不足。**没有统一处理无 Git Artifact key、CI 并行输出、共享缓存、内容
   寻址大文件、敏感材料和数据库/发布副作用。
5. **事故恢复不完整。**写前防护较强，但事后没有 Luna §7.8 那种停写、保全、分流、溯源、
   恢复、裁决、回归的完整链路。
6. **保留规则过度绝对。**L608 写“决策记录与证据账永不删”；长期系统应按审计、隐私、法规
   和保留期分类，敏感证据尤其不能无限期保存。
7. **存在失效链接。**与 Cursor 相同，`../../working/collaboration.md` 和
   `../../working/doc-conventions.md` 在当前 worktree 中不存在。

### 7.3 可吸收内容

吸收“写前五问”和按三层分类场景的表达；把“强制助手后缀”改为：独立 worktree 允许相同
相对路径，只有候选集合需要在同一树中共存时才使用 owner namespace/后缀。

## 8. Luna 候选

### 8.1 成立之处

- L95—L159 给出 Agent 与 Human 两条完整路径；L141—L143 明确 FastAPI/后端供给工作仓、
  supervisor 负责后续派工和整合；
- L74—L93 把事故提升为全程不变量：**私有地产生，单写者发布**，并明确最终文件名属于
  publication target；
- L199—L220、L253—L321 把 owner、writable root、output namespace、integrator 和
  materialization manifest 前置到 Task 与物化门禁，而非事后补救；
- L445—L460 要求每个并行执行者独立 branch/worktree，最终路径只由 integrator 写；
- L519—L695 给出完整产出生命周期：身份、命名空间、九类载体、候选状态机、Git 对象语义、
  多场景矩阵、条件式发布、事故恢复和垃圾回收；
- L611 起的场景表覆盖 Git、共享物理目录、多仓、重试、CI、缓存、大文件、敏感数据、外部
  副作用、远端推送、PR 漂移、迟到、取消和崩溃；
- L657—L663 要求发布校验预期 HEAD/version，以 CAS 方式拒绝静默覆盖；
- L666—L680 的事故流程先停写和保全，再分流、溯源、恢复、裁决和回归，不会用删除制造
  第二次损失；
- L797 起的完成判据和 L850 起的 Task 模板均已纳入 owner/provenance/publication。

### 8.2 缺口与代价

1. **篇幅最长。**908 行会增加阅读成本；§7 场景表与 §13 反模式存在少量语义重复。
2. **项目专用 Git 口令不如 Cursor 直接。**例如“人的主 checkout 不是投稿箱”和写前四问，
   Luna 用抽象的 shared publication plane/owner namespace 表达，准确但不够醒目。
3. **目标合同较强。**CAS、内容寻址 Artifact、integrator ID 等是目标要求，当前实现可能没有；
   必须继续保留“未实现不等于合同缺陷、不能宣称已有”的边界。
4. **本候选由评审者本人撰写。**即使分数领先，也仍需独立方在最终采用前复核上述行号与
   四份冻结 hash。

这些问题影响维护成本和最终终审独立性，不构成本轮硬要求失败。

## 9. 选择结论

本轮选择：

```text
selected_candidate = Luna
selected_sha256 = 6cdcfb85dc0d21f8489cf806d25577590857d1eb33b611b63359a54d03bb3b44
status = SELECTED_FOR_INTEGRATION
```

理由不是 Luna 场景数量最多，而是它形成了其他两稿没有闭合的链：

```text
Task 前置分配 owner / writable root / publication target
  → 候选在独占空间生成
  → commit/digest 冻结
  → supervisor 选定
  → 唯一 integrator 整合
  → 用预期 HEAD/version 条件发布
  → 覆盖时先保全再恢复
  → 引用清零且对象可达后垃圾回收
```

这条链既能解释本次 Markdown 覆盖，也能统一处理源码 commit、未跟踪草稿、CI 输出、大文件、
对象存储、敏感材料和外部副作用。

## 10. 整合建议

本轮不修改被冻结的四份候选。若后续以 Luna 为基线形成 final，应建立新的 integrator
worktree/branch，并逐项处置：

1. 吸收 Cursor 的“人的主 checkout 不是投稿箱”，吸收 Qwen 的五项写前检查；
2. 从 Cursor S1 删除“删除共享路径文件”的危险动作，统一引用 Luna §7.8；
3. 吸收 Cursor 高频 Git 场景中 Luna 未直接点名的 amend、强推共享分支、handoff 单写者；
4. 吸收 Qwen 按“执行者与产出类型 / 生命周期阶段 / 冲突风险”三层组织场景的表达；
5. 不吸收 Qwen 的普遍文件后缀规则；仅在多个候选需共存于同一树时使用 owner namespace；
6. 吸收 Kimi“临时文档删除前，长期纪律必须进入代码/测试/门禁”的生效边界；
7. 压缩 Luna §7 与 §13 的重复表述，但不删除 CAS 发布、非 Git Artifact 和事故保全；
8. 修正最终文档标题，去掉候选作者名；
9. 在新的 final commit 上重新检查链接、Markdown 结构和全部要求，不沿用候选自检。

完成这些动作前，本结论只能称 `SELECTED_FOR_INTEGRATION`，不能称为 final、approved 或
published。
