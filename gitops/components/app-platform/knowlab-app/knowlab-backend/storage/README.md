# knowlab 对象存储（用户数据）

用户上传的数据只放 knowlab 自己的桶（[SDD 0027](../../../../../../docs/design/SDD/modules/0027-knowbot-first-path.md) 决定 4：按用户分前缀，单文件 ≤ 50 MB、每人 ≤ 1 GB，先收 PDF、Excel、CSV、文本）。配置是[后端config](../config.yaml)的 `object_storage`，机制在[应用对象存储](../../../common/backend/storage/README.md)：桶 `knowlab-originals`、身份 `knowlab_storage`（名字由机制规定），桶开版本控制，应用只能读写自己桶的对象、打删除标记，删不了历史版本。用户「删除」一份数据只打删除标记，历史版本留在桶里直到有生命周期策略（尚未实现）。

本目录的 `workload.yaml`、`provision.sops.yaml`、`kustomization.yaml` 由 stage 生成，不手改；生成前目录只有本说明（`stages.py` 要求阶段目录存在）。私有输入 `s3.yaml` 首次 stage 时生成，主备逐字节一致，丢了先恢复，不重新生成。
