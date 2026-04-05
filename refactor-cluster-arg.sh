#!/usr/bin/env bash
set -euo pipefail

# 批量收敛 cluster 参数解析：
# - 删除各脚本自定义的 parse_cluster_arg() 实现
# - 将调用点统一替换为 unified_parse_cluster_arg "$@"
# - 对未引入统一模板的脚本，自动插入轻量解析器（不带连接管理/trap 副作用）
#
# 用法：
#   /home/zym/k8s/refactor-cluster-arg.sh --dry-run
#   /home/zym/k8s/refactor-cluster-arg.sh --apply
# 可选：
#   --root /home/zym/k8s

ROOT="/home/zym/k8s"
MODE="dry-run"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --apply) MODE="apply"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

cd "$ROOT"

# 轻量解析器（只做集群参数解析，不引入 unified-deployment-template 的 trap/连接逻辑）
PARSER="$ROOT/utils/cluster-arg-parser.sh"
if [[ ! -f "$PARSER" ]]; then
  mkdir -p "$(dirname "$PARSER")"
  cat > "$PARSER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 仅提供集群参数解析：--cluster/-c/-c2
# 输出：
#   - export CLUSTER=...
#   - PARSED_ARGS（移除 cluster 参数后的剩余参数）
unified_parse_cluster_arg() {
  local args=("$@")
  PARSED_ARGS=()
  local cluster_value=""
  local i=0

  while [[ $i -lt ${#args[@]} ]]; do
    shopt -s nocasematch
    case "${args[$i]}" in
      --[cC][lL][uU][sS][tT][eE][rR]=*)
        cluster_value="${args[$i]#*=}"
        ;;
      --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
        if [[ $((i+1)) -lt ${#args[@]} ]]; then
          cluster_value="${args[$((i+1))]}"
          i=$((i+1))
        else
          echo "❌ --cluster 参数需要指定值（格式：C{数字} 或 -c2、-c 2 等）" >&2
          exit 1
        fi
        ;;
      -[cC][0-9]*)
        cluster_value="${args[$i]#-[cC]}"
        ;;
      *)
        PARSED_ARGS+=("${args[$i]}")
        ;;
    esac
    shopt -u nocasematch
    i=$((i+1))
  done

  if [[ -n "$cluster_value" ]]; then
    cluster_value="$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')"
    [[ "$cluster_value" =~ ^[0-9]+$ ]] && cluster_value="C${cluster_value}"
    export CLUSTER="$cluster_value"
  fi
}
EOF
  chmod +x "$PARSER" || true
fi

# 获取包含 parse_cluster_arg() 的文件列表
if command -v rg >/dev/null 2>&1; then
  # 忽略备份文件
  mapfile -t FILES < <(rg -l '^\s*parse_cluster_arg\(\)\s*\{' "$ROOT" --glob '!**/*.bak' || true)
else
  # grep 兜底：简单过滤 .bak
  mapfile -t FILES < <(grep -RIlE '^[[:space:]]*parse_cluster_arg\(\)[[:space:]]*\{' "$ROOT" | grep -v '\.bak$' || true)
fi

echo "找到包含 parse_cluster_arg() 的文件数: ${#FILES[@]}"
[[ "${#FILES[@]}" -eq 0 ]] && exit 0

python3 - <<'PY' "$MODE" "$ROOT" "$PARSER" "${FILES[@]}"
import sys, re, os
mode = sys.argv[1]
root = sys.argv[2]
parser = sys.argv[3]
files = sys.argv[4:]

def remove_all_functions(text: str):
    # 移除：parse_cluster_arg() { ... }（同一文件可能出现多次，需循环删除）
    pat = re.compile(r'^\s*parse_cluster_arg\(\)\s*\{\s*$', re.M)
    removed_any = False
    while True:
        m = pat.search(text)
        if not m:
            return text, removed_any
        start = m.start()
        i = m.end()
        depth = 1
        while i < len(text) and depth > 0:
            nl = text.find('\n', i)
            if nl == -1:
                line = text[i:]
                i = len(text)
            else:
                line = text[i:nl+1]
                i = nl+1
            depth += line.count('{')
            depth -= line.count('}')
        end = i
        text = text[:start] + text[end:]
        removed_any = True

def ensure_parser_import(text: str):
    # 若已 source unified-deployment-template，则不额外插入 parser
    if "unified-deployment-template.sh" in text:
        return text, False
    # 若已引入 cluster-arg-parser，也不插入
    if "cluster-arg-parser.sh" in text:
        return text, False

    lines = text.splitlines(True)
    insert_at = None
    for idx, line in enumerate(lines):
        if re.search(r'^\s*PROJECT_ROOT\s*=', line):
            insert_at = idx + 1
            break
    if insert_at is None:
        insert_at = 1 if lines and lines[0].startswith("#!") else 0

    snippet = '\n# 集群参数解析（轻量，无连接副作用）\nsource "$PROJECT_ROOT/utils/cluster-arg-parser.sh"\n\n'
    lines.insert(insert_at, snippet)
    return "".join(lines), True

def replace_calls(text: str):
    n = 0
    def sub(m):
        nonlocal n
        n += 1
        return m.group(0).replace("parse_cluster_arg", "unified_parse_cluster_arg")
    text2 = re.sub(r'\bparse_cluster_arg\s+"\$@"', sub, text)
    return text2, n

changed = 0
for path in files:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        old = f.read()
    new = old

    new, removed = remove_all_functions(new)
    new, repl_n = replace_calls(new)
    new, inserted = ensure_parser_import(new)

    if new != old:
        changed += 1
        if mode == "apply":
            bak = path + ".bak"
            if not os.path.exists(bak):
                with open(bak, "w", encoding="utf-8", errors="ignore") as f:
                    f.write(old)
            with open(path, "w", encoding="utf-8", errors="ignore") as f:
                f.write(new)
        print(f"[CHG] {path}")
        if removed:
            print("  - removed parse_cluster_arg()")
        if repl_n:
            print(f"  - replaced call sites: {repl_n}")
        if inserted:
            print("  - inserted cluster-arg-parser import")
    else:
        print(f"[SKIP] {path}")

print(f"\n总计变更文件: {changed}/{len(files)}")
if mode != "apply":
    print("\n当前为 DRY-RUN。要真正写入文件，请加 --apply")
PY

echo
echo "校验（应为 0，不包含 .bak）："
if command -v rg >/dev/null 2>&1; then
  rg -n '^\s*parse_cluster_arg\(\)\s*\{' "$ROOT" --glob '!**/*.bak' || true
else
  grep -RInE '^[[:space:]]*parse_cluster_arg\(\)[[:space:]]*\{' "$ROOT" | grep -v '\.bak:' || true
fi
