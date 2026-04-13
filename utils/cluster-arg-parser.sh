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
