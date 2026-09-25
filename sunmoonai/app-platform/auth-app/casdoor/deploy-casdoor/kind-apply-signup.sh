#!/usr/bin/env bash
# KIND：只跑自助注册这一步（signup-setup.sh）——注册页、登录页的中文与品牌、关掉 Casdoor 自带应用的注册、
# 可选的首个邀请码与发信服务。不需要 post-deploy-setup.local.conf 里各应用的密钥。
#
# 用法（在本地机）：
#   bash kind-apply-signup.sh                      # 没配发信服务：注册保持关闭，只改页面
#   SIGNUP_ENV=~/private/casdoor-signup.env bash kind-apply-signup.sh   # 文件里写 SIGNUP_SMTP_* 等（见 signup-setup.sh 头部）
#
# 连库方式：kubectl exec 进 data-platform-dev/postgresql-sunmoonai-0，在 pod 里读口令文件，口令不出 pod、不上屏。
# 测试时可用 PSQL_EXEC 换成别的连法（例如 docker exec）。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/kind-config}"

log_info()  { echo "[INFO]  $*"; }
log_ok()    { echo "[OK]    $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }
sql_escape_single() { printf '%s' "${1//\'/\'\'}"; }

if [[ -z "${PSQL_EXEC:-}" ]]; then
  run_sql() {
    kubectl --kubeconfig "$KUBECONFIG_PATH" -n data-platform-dev exec -i postgresql-sunmoonai-0 -c postgresql -- \
      sh -c 'PGPASSWORD="$(cat "$POSTGRES_POSTGRES_PASSWORD_FILE")" psql -h 127.0.0.1 -U postgres -d casdoor -v ON_ERROR_STOP=1 -q' <<<"$1"
  }
else
  run_sql() { $PSQL_EXEC <<<"$1"; }
fi

if [[ -n "${SIGNUP_ENV:-}" ]]; then
  [[ -r "$SIGNUP_ENV" ]] || { log_error "读不到 $SIGNUP_ENV"; exit 1; }
  # shellcheck disable=SC1090
  set -a; source "$SIGNUP_ENV"; set +a
fi
# KIND 的投资网页应用名是 sunmoonai-investment-r5-web（由身份供给流程建，不是 post-deploy-setup 的 APP_8 名）
export SIGNUP_APP="${SIGNUP_APP:-sunmoonai-investment-r5-web}" SIGNUP_ORG="${SIGNUP_ORG:-sunmoonai}"

run_sql "SELECT 1;" >/dev/null || { log_error "连不上 Casdoor 数据库（kubectl / pod / 口令文件）"; exit 1; }
# shellcheck source=signup-setup.sh
source "$HERE/signup-setup.sh"
setup_signup || exit 1
log_ok "完成。改了什么以上面几行 [OK] 为准；注册开没开看最后一行的「注册=」"
