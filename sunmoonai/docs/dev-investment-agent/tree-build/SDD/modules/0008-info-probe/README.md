# info 平台财务数据的探针与研究（2026-09-28）的原件

> 这里是当时的报告、脚本与备忘，原样留存，**不是活文档**。结论与决定已并入
> [`0008-info-statements`](../0008-info-statements.md) 与 [决策](../../../decisions.md)，以那两处为准。
> 当时在远程机家目录下做，没有动任何仓库里的代码。

| 文件 | 内容 |
| --- | --- |
| `single/REPORT.md` | 探针一：从 600009 的九份年报抽三大报表 |
| `single/step1_text.py`、`step2_extract.py`、`step3_compare.py` | 探针一的脚本 |
| `batch/REPORT.md` | 探针二：扩大到 14 家公司 |
| `batch/companies.tsv`、`run_ingest.sh`、`extract_company.py`、`compare_all.py`、`summary.txt` | 探针二的公司清单、脚本与汇总表 |
| `memo-pdf-xbrl-qlib.md` | 备忘：PDF 的三种用途、交易所 XBRL 的现状、Qlib 的实际情况、数与文的关系 |
| `research-where-to-keep-structured-data.md` | 研究：结构化数据放在哪 |

没有留存的：

| 没留的 | 原因 |
| --- | --- |
| 年报原件、每页的文字、抽出的每一行 | 体积大；年报可以重新采集，抽取可以用脚本重跑 |
| 各公司的数据集文件 | 内容来自第三方网站，仅供内部使用 |
| 查证交易所与巨潮时取到的原始返回 | 同上。备忘里提到的 `evidence/` 目录指的是它们，在远程机家目录 `~/data-source-memo-2026-09-28/evidence/` |

脚本里的路径是当时的写法（`~/annual-report-probe/`、`~/info-smoke-storage/`），重跑要先改路径。

备忘里有一处后来被所有者纠正：年报原件**全部保留**，一部分在本机，其余在外存储；备忘与研究稿里「原件抽完后不长期留」的说法是远程当时的建议，没有被采纳。
