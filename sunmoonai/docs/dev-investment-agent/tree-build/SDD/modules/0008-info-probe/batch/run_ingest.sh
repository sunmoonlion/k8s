#!/usr/bin/env bash
# 批量采集并建数据集：用 info 后端已有的命令行，不改任何代码。
# 采集走巨潮与东方财富，每个请求之间有停顿；结果进一次性的测试库与本机存储目录。
set -uo pipefail
HERE="$HOME/annual-report-probe/batch"
: "${DATABASE_URL:?要设 DATABASE_URL，指向一次性的测试库}"
export CRAWL_MAX_BYTES=47185920 STORAGE_LOCAL_ROOT=$HOME/info-smoke-storage STORAGE_BACKEND=local ENV=development
cd "$HOME/worktrees/fable/info-app/info-backend/app" || exit 1
while IFS=$'\t' read -r code name board industry; do
  [ -f "$HERE/logs/$code.done" ] && continue
  start=$(date +%s)
  uv run python -m app.cli.security_ingest --code "$code" >"$HERE/logs/$code.ingest.json" 2>"$HERE/logs/$code.ingest.err"; a=$?
  uv run python -m app.cli.security_dataset --code "$code" --out "$HERE/datasets/$code.sqlite" >"$HERE/logs/$code.dataset.json" 2>"$HERE/logs/$code.dataset.err"; b=$?
  echo "$code $name ingest_exit=$a dataset_exit=$b seconds=$(( $(date +%s) - start ))" >>"$HERE/logs/progress.txt"
  touch "$HERE/logs/$code.done"
  sleep 5
done <"$HERE/companies.tsv"
echo "ALL DONE" >>"$HERE/logs/progress.txt"
