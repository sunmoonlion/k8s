"""生成「财务分析与预测」第 1 版的专家清单（knowbot-manifest/v1）。

方法只来自所有者 2026-10-18 的答复（决定单 docs/财务分析与预测-待你定.md、0029 第 4 步六问）；
这里只做工程化：8 步一一对应、每步的交回物、验收、工具。用法：
    python3 fin_manifest.py <输出路径> [<workbook 数据集id> <版本> <sha256> [<年份>=<id>:<版本>:<sha256> ...]]
不给数据绑定时写占位（只用来核结构）。
"""

from __future__ import annotations

import json
import sys

VERSION = "1"
SHEETS = "资产负债表、利润表、现金流量表、主要会计数据"
REF = "2026-10-18 所有者答 {g}：「{words}」"

COMMON = (
    "Pass the task id given in the step instructions on every tool call. Use only the "
    "user's own data through list_my_data, read_my_data and read_my_table: no web, no "
    "memory, no other source. A cell address is <dataset_id>:<sheet>!<row label>@<column "
    "label>, with the labels copied exactly as read_my_table shows them (a repeated label "
    "carries #2). Never type, copy or work out a number yourself: every number you hand "
    "back is either a table cell with its address, or the result of compute with its "
    "compute id (ids are not consecutive; that is normal). If the scope artifact says "
    "in_data is false, do no work in this step: return the structure with empty lists and "
    "note 'no data for this company'. Describe, do not judge: no rating, target price, or "
    "advice to buy, sell or hold. "
)
JSON_ONLY = (
    "Reply with ONE JSON object only, no markdown fences, no commentary before or after "
    "it. Do not modify any files for this step unless the step says so."
)


def rule(kind: str, label: str, message: str, **kw) -> dict:
    return {"kind": kind, "label": label, "message": message, **kw}


def fmt(keys: list[str]) -> list[dict]:
    return [
        rule("json_object", "交回的格式对", "交回物不是 JSON 对象"),
        rule("required_keys", "该有的都有", "缺了 " + "、".join(keys), keys=keys),
    ]


def computed(path: str, expression: str | None, label: str) -> dict:
    extra = {"expression": expression} if expression else {}
    return rule(
        "computed",
        label,
        f"{path} 里有数不是由平台按规定的算式算出来的",
        path=path,
        **extra,
    )


def sourced(path: str, label: str) -> dict:
    return rule("sourced", label, f"{path} 里有数和你表里那一格对不上", path=path)


ITEM = {"period": "string", "compute_id": "c…", "value": "string"}

STEPS = [
    {
        "step_id": "scope",
        "title": "定范围",
        "summary": "看问题问的是哪家公司、要哪些科目和指标、要不要预测；你的数据里没有这家公司就停下说明",
        "why": "公司不在你的数据里就不往下做，也不去别处找（你答的第 12 条）",
        "tools": ["list_my_data", "read_my_table"],
        "method_text": COMMON
        + "Read the question and name the company. Call list_my_data and look at the titles "
        "and file names of the user's data: one workbook (an Excel file with the sheets "
        f"{SHEETS}) and the annual report PDFs. in_data is true only when the user's data is "
        "about this company. If it is not, set in_data false, say in note which company was "
        "asked and that the user's data does not cover it, and stop: do not look anywhere "
        "else. When in_data is true fill: workbook (its dataset id and the sheet names as "
        "read_my_table shows them); reports (one entry per annual report PDF: year and "
        "dataset id); items (the line items or indicators the question names, written as "
        "in the question); forecast_quarters (how many quarters the question asks to "
        "forecast, at most 4; 0 if it asks none); extra_flow_items (flow line items the "
        "question names other than revenue and net profit attributable to the parent, to "
        "be forecast as well). If the same line item appears under two bases in the "
        "workbook (for example consolidated and parent-company figures mixed together), "
        "ask the user which one to use before going on (one question). ",
        "output_artifact": "scope",
        "output_schema": {
            "company": "string",
            "in_data": True,
            "workbook": {"dataset_id": "string", "sheets": ["string"]},
            "reports": [{"year": "string", "dataset_id": "string"}],
            "items": ["string"],
            "forecast_quarters": 0,
            "extra_flow_items": ["string"],
            "note": "string",
        },
        "acceptance": fmt(
            ["company", "in_data", "workbook", "reports", "items", "forecast_quarters", "note"]
        ),
    },
    {
        "step_id": "inventory",
        "title": "数据摸底",
        "summary": "列出你的数据里有哪些表、哪些报告期、哪些科目，缺了什么；期数够不够回测和预测",
        "why": "缺的照实列出，能做的照做（你答的第 12 条）",
        "input_refs": ["scope"],
        "tools": ["read_my_table"],
        "method_text": COMMON
        + "Read every sheet of the workbook with read_my_table, all pages. For each sheet list "
        "the periods (column labels) and the line items (row labels) exactly as shown. "
        "single_quarters is the number of quarterly periods in 利润表 from the earliest to "
        "the latest without a gap (each quarterly period gives one single quarter). "
        "can_backtest and can_forecast are true when single_quarters is at least 12. "
        "missing lists every line item the method needs that the workbook lacks, and every "
        "empty cell among those items, with sheet, item, period and why it matters. The "
        "method needs: 资产总计, 负债合计, 所有者权益合计, 归属于母公司所有者权益合计 "
        "(资产负债表); 营业收入, 营业成本, 净利润, 归属于母公司所有者的净利润, 少数股东损益, "
        "扣除非经常性损益后的归属于母公司股东的净利润 (利润表); 经营活动产生的现金流量净额, "
        "现金及现金等价物净增加额, 期初现金及现金等价物余额, 期末现金及现金等价物余额 "
        "(现金流量表); the five rows of 主要会计数据. The user may word a label slightly "
        "differently (股东 for 所有者, for example): match by meaning and record the label as "
        "written. Do not compute anything. ",
        "output_artifact": "inventory",
        "output_schema": {
            "sheets": [{"name": "string", "periods": ["string"], "items": ["string"]}],
            "single_quarters": 0,
            "can_backtest": True,
            "can_forecast": True,
            "missing": [{"sheet": "string", "item": "string", "period": "string", "why": "string"}],
            "note": "string",
        },
        "acceptance": fmt(["sheets", "single_quarters", "can_backtest", "can_forecast", "missing"]),
        "input_max_chars": 20000,
    },
    {
        "step_id": "reconcile",
        "title": "勾稽",
        "summary": "查四条会计恒等式，差额超过 1 元算不平；不平的照实列出，那几期不进预测",
        "why": "数先对得上，后面的指标和预测才站得住（你答的第 3 条）",
        "input_refs": ["scope", "inventory"],
        "tools": ["read_my_table", "compute"],
        "method_text": COMMON
        + "Run four checks with compute, round 2. (1) For every period of 资产负债表: names a "
        "(资产总计), l (负债合计), e (所有者权益合计), expression `a - (l + e)`; put each into "
        "bs_check. (2) For every period of 利润表: p (归属于母公司所有者的净利润), m (少数股东损益), "
        "n (净利润), expression `p + m - n`; into np_check. (3) For every period of "
        "现金流量表: e (期末现金及现金等价物余额), b (期初现金及现金等价物余额), d "
        "(现金及现金等价物净增加额), expression `e - (b + d)`; into cash_check. (4) For every "
        "year-end column (YYYY-12-31) of 现金流量表 except the first: o (this year's "
        "期初现金及现金等价物余额), c (the previous year-end's 期末现金及现金等价物余额), "
        "expression `o - c`; into opening_check, period = this year-end. Each entry is "
        "{period, compute_id, value, balanced} where balanced is true when the difference is "
        "at most 1 in absolute value (the unit is yuan). unbalanced lists every check that is "
        "not balanced with its name, period and difference; excluded_periods lists those "
        "periods, which stay out of the forecast window. A check that cannot run because a "
        "cell is empty goes into skipped with the reason; never fill a gap. ",
        "output_artifact": "reconcile",
        "output_schema": {
            "bs_check": [dict(ITEM, balanced=True)],
            "np_check": [dict(ITEM, balanced=True)],
            "cash_check": [dict(ITEM, balanced=True)],
            "opening_check": [dict(ITEM, balanced=True)],
            "unbalanced": [{"check": "string", "period": "string", "value": "string"}],
            "excluded_periods": ["string"],
            "skipped": [{"check": "string", "period": "string", "why": "string"}],
            "note": "string",
        },
        "acceptance": fmt(
            ["bs_check", "np_check", "cash_check", "opening_check", "unbalanced", "excluded_periods"]
        )
        + [
            computed("bs_check", "a - (l + e)", "资产 = 负债 + 所有者权益，由平台算"),
            computed("np_check", "p + m - n", "归母 + 少数 = 净利润，由平台算"),
            computed("cash_check", "e - (b + d)", "期末现金 = 期初 + 净增加，由平台算"),
            computed("opening_check", "o - c", "今年期初现金 = 去年期末现金，由平台算"),
        ],
        "input_max_chars": 20000,
    },
    {
        "step_id": "series",
        "title": "取数",
        "summary": "把累计数换成单季：Q2 = 半年 − Q1，Q3 = 三季 − 半年，Q4 = 年报 − 三季；资产负债表不换",
        "why": "预测按单季做，单季的数要能一个个核回你的表（你答的第 4 条）",
        "input_refs": ["scope", "inventory"],
        "tools": ["read_my_table", "compute"],
        "method_text": COMMON
        + "Build single quarters for 营业收入 and 归属于母公司所有者的净利润, and for every item "
        "in scope.extra_flow_items, over every quarterly period of 利润表 (现金流量表 for "
        "cash-flow items). Q1 (period ending 03-31) is the cumulative cell itself: put it into "
        "q1 as {item, period, address, value}. Q2, Q3 and Q4: compute with names cum (this "
        "period's cumulative cell) and prev (the previous period's cumulative cell of the "
        "same year), expression `cum - prev`, round 2; put it into derived as {item, period, "
        "compute_id, value}. 资产负债表 holds point figures: do not convert it. ",
        "output_artifact": "series",
        "output_schema": {
            "q1": [{"item": "string", "period": "string", "address": "string", "value": "string"}],
            "derived": [{"item": "string", "period": "string", "compute_id": "c…", "value": "string"}],
            "note": "string",
        },
        "acceptance": fmt(["q1", "derived"])
        + [
            sourced("q1", "一季度的数与表里一致"),
            computed("derived", "cum - prev", "单季由平台按 累计 − 上一期累计 算"),
        ],
        "input_max_chars": 20000,
    },
    {
        "step_id": "indicators",
        "title": "算指标与分析",
        "summary": "算核心指标：毛利率、净利率、净资产收益率、经营现金流与净利润之比、收入与利润增速；分母不成立的标不适用",
        "why": "口径照你定的写死，分母不成立不硬算（你答的第 5、6 条）",
        "input_refs": ["scope", "inventory"],
        "tools": ["read_my_table", "compute"],
        "method_text": COMMON
        + "For every year-end column (YYYY-12-31), using the full-year cells, compute round 4: "
        "gross_margin `(rev - cost) / rev` (营业收入, 营业成本); net_margin `np / rev` (np = "
        "归属于母公司所有者的净利润); roe `np / ((open + close) / 2)` with open = the previous "
        "year-end 归属于母公司所有者权益合计 and close = this year-end's (the first year has "
        "no opening value: not applicable); cash_ratio `ocf / np` (ocf = "
        "经营活动产生的现金流量净额); revenue_growth `(cur - prev) / prev` on 营业收入 against "
        "the previous full year; profit_growth the same on 归属于母公司所有者的净利润. Each "
        "entry is {period, compute_id, value}. When a denominator is zero, negative or "
        "missing, do not compute: put {indicator, period, reason} into not_applicable. For the "
        "line items the question names (scope.items), list their year-end cells in values as "
        "{item, period, address, value}. Anything the question asks that cannot be derived "
        "from the user's data goes into not_available as {item, reason}. findings describe "
        "the trends in plain Chinese sentences, each naming the figures it rests on; describe "
        "only, never call a figure good or bad. ",
        "output_artifact": "indicators",
        "output_schema": {
            "gross_margin": [ITEM],
            "net_margin": [ITEM],
            "roe": [ITEM],
            "cash_ratio": [ITEM],
            "revenue_growth": [ITEM],
            "profit_growth": [ITEM],
            "values": [{"item": "string", "period": "string", "address": "string", "value": "string"}],
            "not_applicable": [{"indicator": "string", "period": "string", "reason": "string"}],
            "not_available": [{"item": "string", "reason": "string"}],
            "findings": ["string"],
            "note": "string",
        },
        "acceptance": fmt(
            ["gross_margin", "net_margin", "roe", "cash_ratio", "revenue_growth", "profit_growth",
             "not_applicable", "not_available", "findings"]
        )
        + [
            computed("gross_margin", "(rev - cost) / rev", "毛利率按你的口径由平台算"),
            computed("net_margin", "np / rev", "净利率按你的口径由平台算"),
            computed("roe", "np / ((open + close) / 2)", "净资产收益率按平均归母净资产由平台算"),
            computed("cash_ratio", "ocf / np", "经营现金流与净利润之比由平台算"),
            computed("revenue_growth", "(cur - prev) / prev", "营收同比由平台算"),
            computed("profit_growth", "(cur - prev) / prev", "归母净利润同比由平台算"),
            sourced("values", "问到的科目与表里一致"),
            rule("no_positioning_advice", "没有评价好坏、买卖建议", "发现里出现了评价或买卖建议类措辞", path="findings"),
        ],
        "input_max_chars": 20000,
    },
    {
        "step_id": "official",
        "title": "对照官方披露",
        "summary": "先核你抄的「主要会计数据」和年报原文一致，再拿三张表和它比：相对差超过 0.1% 算对不上；净资产收益率口径不同，只并列",
        "why": "对不上的两个数都列出，以年报为准（你答的第 7 条）",
        "input_refs": ["scope", "inventory", "indicators"],
        "tools": ["read_my_data", "read_my_table", "compute"],
        "method_text": COMMON
        + "The user copied each annual report's 主要会计数据和财务指标 into the sheet "
        "主要会计数据. First check that copy: for every year read that year's annual report PDF "
        "with read_my_data, find the section 主要会计数据和财务指标, and for each of its five "
        "rows note the page and whether the sheet's number is the one printed there; put "
        "{year, item, page, matches} into copy_checks (compare the digits as printed; do not "
        "compute). Then for every year, compare the workbook with the sheet for four items: "
        "营业收入 and 归属于母公司所有者的净利润 (利润表), 扣除非经常性损益后的归属于母公司股东的净利润 "
        "(the extra row of 利润表), 经营活动产生的现金流量净额 (现金流量表), each against its "
        "row of 主要会计数据: compute with names ours and official, expression `(ours - "
        "official) / official`, round 6; put {item, year, compute_id, value, matches} into "
        "diffs, matches being true when the absolute value is at most 0.001. List every sheet "
        "cell you used in official_values as {item, year, address, value}. For "
        "加权平均净资产收益率 put {year, official_address, official_value, ours_compute_id, "
        "ours_value} into roe_pairs, ours from indicators.roe, with note '口径不同（年报加权平均"
        " vs 本方法期初期末平均）': list both, never judge whether they match. mismatches "
        "repeats every diff that does not match with both numbers; the write-up follows the "
        "annual report. official_by_year restates, per year, the sheet's 营业收入 as "
        "{\"<year>\": {\"revenue\": \"<the cell value>\"}}. ",
        "output_artifact": "official",
        "output_schema": {
            "copy_checks": [{"year": "string", "item": "string", "page": 0, "matches": True}],
            "official_values": [{"item": "string", "year": "string", "address": "string", "value": "string"}],
            "diffs": [{"item": "string", "year": "string", "compute_id": "c…", "value": "string", "matches": True}],
            "roe_pairs": [{"year": "string", "official_address": "string", "official_value": "string",
                           "ours_compute_id": "c…", "ours_value": "string", "note": "string"}],
            "mismatches": [{"item": "string", "year": "string", "ours": "string", "official": "string"}],
            "official_by_year": {"2024": {"revenue": "string"}},
            "note": "string",
        },
        "acceptance": fmt(["copy_checks", "official_values", "diffs", "roe_pairs", "mismatches", "official_by_year"])
        + [
            sourced("official_values", "抄的主要会计数据与表里一致"),
            computed("diffs", "(ours - official) / official", "相对差由平台算"),
        ],
        "input_max_chars": 20000,
    },
    {
        "step_id": "forecast",
        "title": "预测",
        "summary": "季节性同比：下一季 = 上年同季 ×（1 + 近 4 季同比中位数），区间用近 8 季同比的最小、最大；先回测最近 4 季",
        "why": "方法、回测、区间、假设都写明，不是承诺（你答的第 8、9 条）",
        "input_refs": ["scope", "inventory", "reconcile", "series"],
        "tools": ["compute"],
        "method_text": COMMON
        + "Forecast 营业收入 and 归属于母公司所有者的净利润, plus every item in "
        "scope.extra_flow_items. Build each single-quarter series from series.q1 (use the "
        "address) and series.derived (use the compute id), oldest to newest, leaving out "
        "reconcile.excluded_periods. All inputs are addresses or compute ids, never numbers. "
        "(a) yoy: for every quarter that has the same quarter a year before, compute "
        "`(cur - prev) / prev`, round 6, as {item, period, compute_id, value}. (b) If "
        "inventory.can_forecast is false or scope.forecast_quarters is 0, forecast nothing and "
        "say why in note. Otherwise compute the rates: `median(g)` over the latest 4 yoy ids, "
        "`min(g)` and `max(g)` over the latest 8, as {item, kind (median, min or max), "
        "for_period ('next'), compute_id, value}. For each forecast quarter h = 1 … "
        "scope.forecast_quarters: base = the single quarter of the same quarter one year "
        "before; compute `base * (1 + g)` three times, with g the median (point), the min "
        "(low) and the max (high), round 2, as {item, period, kind (point, low or high), "
        "compute_id, value}. horizon is the number of quarters forecast. (c) Backtest only "
        "when inventory.can_backtest is true: for each of the latest 4 actual quarters t, "
        "compute the median of the 4 yoy before t and the min and max of the 8 yoy before t "
        "(rates with for_period t), then `base * (1 + g)` for point, low and high with base = "
        "the same quarter one year before t (backtest entries {item, period, kind, "
        "compute_id, value}), then the error `abs(pred - actual) / actual` with pred the point "
        "and actual the quarter's own value, round 6 (errors {item, period, compute_id, "
        "value, in_range}, in_range true when actual lies between low and high), then "
        "`avg(e)` over the 4 errors per item (mean_errors {item, compute_id, value}). Without "
        "12 single quarters there is no backtest: say why in note. (d) Ratios are not "
        "extrapolated on their own. assumptions: at least two, including that recent growth "
        "continues and that there is no major change of basis or business. ",
        "output_artifact": "forecast",
        "output_schema": {
            "yoy": [{"item": "string", "period": "string", "compute_id": "c…", "value": "string"}],
            "rates": [{"item": "string", "kind": "string", "for_period": "string", "compute_id": "c…", "value": "string"}],
            "forecasts": [{"item": "string", "period": "string", "kind": "string", "compute_id": "c…", "value": "string"}],
            "backtest": [{"item": "string", "period": "string", "kind": "string", "compute_id": "c…", "value": "string"}],
            "errors": [{"item": "string", "period": "string", "compute_id": "c…", "value": "string", "in_range": True}],
            "mean_errors": [{"item": "string", "compute_id": "c…", "value": "string"}],
            "horizon": 0,
            "assumptions": ["string"],
            "note": "string",
        },
        "acceptance": fmt(["yoy", "rates", "forecasts", "backtest", "errors", "mean_errors", "horizon", "assumptions"])
        + [
            computed("yoy", "(cur - prev) / prev", "单季同比由平台算"),
            computed("rates", None, "中位数、最小、最大由平台算"),
            computed("forecasts", "base * (1 + g)", "预测按 上年同季 ×（1 + 增速）由平台算"),
            computed("backtest", "base * (1 + g)", "回测按同一方法由平台算"),
            computed("errors", "abs(pred - actual) / actual", "回测误差由平台算"),
            computed("mean_errors", "avg(e)", "平均误差由平台算"),
        ],
        "input_max_chars": 60000,
    },
    {
        "step_id": "writeup",
        "title": "成稿",
        "summary": "写成一篇能逐条核对的稿子：回答、带出处的数据、勾稽与对照、指标与发现、预测表、局限、出处；结论留给你",
        "why": "每个数都有出处，对不上、算不出来的照实写（你答的第 10 条）",
        "input_refs": ["scope", "inventory", "reconcile", "series", "indicators", "official", "forecast"],
        "tools": [],
        "output_file": "底稿/财务分析与预测-成稿.md",
        "method_text": COMMON
        + "Write the deliverable in Chinese from the input artifacts only; do not call any "
        "data tool (writing the file is the only tool use). If scope.in_data is false, the "
        "answer says plainly that the user's data has no data for that company "
        "（你的数据里没有这家公司）and nothing else is analysed. Whenever something cannot be "
        "derived from the user's data, write 算不出来 and why. The file has these sections in "
        "order: 回答 (the answer in plain words: the trends and, when a forecast was asked, the "
        "point and the range of each forecast quarter with the method in one sentence); 数据 "
        "(every number as a table with its source: file, sheet, row, period); 勾稽与对照 "
        "(the four checks and the comparison with the annual reports, mismatches listed with "
        "both numbers, the annual report prevailing; 加权平均净资产收益率 listed beside our "
        "净资产收益率 with the note that the bases differ); 指标与发现 (describe only); 预测 "
        "(method, window, backtest with errors and how many actuals fell in the range, the "
        "ranges, the assumptions; a forecast is an extrapolation, never a promise or a "
        "target); 局限 (everything in inventory.missing, reconcile.unbalanced and skipped, "
        "official.mismatches, indicators.not_applicable and not_available, and any reason "
        "there was no backtest or forecast); 出处 (one line per file: title, dataset id, "
        "version; when scope.in_data is false, the files you looked at); 结论 (left blank for "
        "the user). Do not paste raw JSON into the file. The "
        "JSON reply carries answer, limitations, citations, data_version and an empty "
        "conclusion. ",
        "output_artifact": "note",
        "output_schema": {
            "answer": "string",
            "limitations": ["string"],
            "citations": ["string"],
            "data_version": "string",
            "conclusion": "",
        },
        "acceptance": fmt(["answer", "limitations", "citations", "data_version", "conclusion"])
        + [
            rule("non_empty", "回答不是空的", "回答为空", path="answer"),
            rule("list_min", "有出处", "没有出处", path="citations", min_items=1),
            rule("no_positioning_advice", "没有评级、目标价、买卖建议", "含有评级、目标价或买卖建议的措辞"),
            rule("blank", "结论留给你", "结论栏要留空", path="conclusion"),
            rule("max_chars", "成稿没有超长", "成稿过长", max_chars=40000),
        ],
        "input_max_chars": 60000,
    },
]

# 每条规则的出处：所有者的原话或他确认过的提议（C-L1）
SOURCES = [
    ("分析的科目 = 问题点到的科目 + 固定核心指标；只预测营业收入、归母净利润，比率不单独外推", "user_text", "U2：2026-10-15 所有者「按这个定」"),
    ("数据里没有的不硬算、不冒充，照实说算不出来", "user_text", "U3：「这正是我们要的不硬算、不冒充」"),
    ("逻辑来自用户的想法，数据来自用户的数据", "user_text", "U4：「逻辑来自用户idea，数据来自用户上传的数据」"),
    ("八步：定范围、数据摸底、勾稽、取数、算指标与分析、对照官方披露、预测、成稿；工作步骤一一对应", "user_confirmed", REF.format(g="G0", words="全按提议」「好，按8步来")),
    ("数据：三张表合并报表、按报告期累计数、近 5 年、单位元，加主要会计数据工作表与年报 PDF", "user_confirmed", REF.format(g="G1", words="全按提议」「按建议")),
    ("勾稽四条，差额超过 1 元算不平，不平照实列出、写进局限、不进预测窗口；第 4 条用现金流量表的期初、期末现金", "user_confirmed", REF.format(g="G2", words="全按提议」「按建议")),
    ("累计数换单季：Q2 = 半年 − Q1，Q3 = 三季 − 半年，Q4 = 年报 − 三季；资产负债表不换", "user_confirmed", REF.format(g="G3", words="全按提议")),
    ("核心指标口径：毛利率、净利率（归母）、净资产收益率（平均归母净资产，季度不年化）、经营现金流与净利润之比、同比增速", "user_confirmed", REF.format(g="G4", words="还是全做吧……要保证：规范地做")),
    ("分母为 0、为负或缺数，标不适用并写原因，不算", "user_confirmed", REF.format(g="G5", words="全按提议")),
    ("对照年报主要会计数据：四项相对差超过 0.1% 算对不上、两个数都列、以年报为准；加权平均净资产收益率口径不同，只并列不判", "user_confirmed", REF.format(g="G6", words="按建议")),
    ("预测：季节性同比，下一季 = 上年同季 ×（1 + 近 4 季同比中位数），区间用近 8 季同比最小、最大，至少两条假设", "user_confirmed", REF.format(g="G7", words="全按提议")),
    ("回测最近 4 季，报误差与落进区间的个数；不足 12 季不回测；最多预测 4 季", "user_confirmed", REF.format(g="G8", words="还是全做吧……要保证：规范地做")),
    ("成稿：回答、数据（带出处）、勾稽与对照、指标与发现（只描述）、预测表、局限、出处；结论栏留空", "user_confirmed", REF.format(g="G9", words="全按提议")),
    ("公司不在数据里就停下说明、不去别处找；期数不够照做能做的、写明原因；同一科目两个口径就问用户", "user_confirmed", REF.format(g="G11", words="全按提议")),
]

ANSWERS = {
    "解决什么": "对一家中国 A 股上市公司，用我上传的财报（三张表与年报）：先核数据（勾稽、对照年报披露），再把问题点到的科目和一组固定的核心指标算出来、看清走势；再对营业收入、归母净利润做预测，每个预测都先回测，再给区间和假设。",
    "不解决什么": "不逐科目预测整套报表；比率不单独外推；数据里没有的不硬算、不冒充，照实说算不出来；只做 A 股上市公司；不评价好坏、不下结论，不给买卖建议、评级、目标价。",
}


def manifest(bindings: list[dict]) -> dict:
    return {
        "schema": "knowbot-manifest/v1",
        "name": "财务分析与预测",
        "tagline": "用你的财报核数、算指标、带回测和区间做预测",
        "version": VERSION,
        "runtime": "knowbench",
        "pack": {
            "pack_id": "fin-analysis-forecast",
            "version": VERSION,
            "title": "财务分析与预测",
            "answers": ANSWERS,
            "workflow": STEPS,
        },
        "data_bindings": bindings,
        "rule_sources": [{"rule": r, "source": s, "ref": ref} for r, s, ref in SOURCES],
    }


if __name__ == "__main__":
    out = sys.argv[1]
    bindings = []
    if len(sys.argv) >= 5:
        bindings.append({"dataset_id": sys.argv[2], "version": sys.argv[3], "sha256": sys.argv[4]})
        for extra in sys.argv[5:]:
            _, rest = extra.split("=", 1)
            did, ver, sha = rest.split(":")
            bindings.append({"dataset_id": did, "version": ver, "sha256": sha})
    else:
        bindings.append({"dataset_id": "workbook-placeholder", "version": "1", "sha256": "0" * 64})
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(manifest(bindings), fh, ensure_ascii=False, indent=2)
        fh.write("\n")
