#!/usr/bin/env bash
mongo_validate() {
  require_non_empty APP_DB_NAME "${APP_DB_NAME:-}"
  require_non_empty APP_DB_USER "${APP_DB_USER:-}"
  require_non_empty APP_DB_PASSWORD "${APP_DB_PASSWORD:-}"
  if [[ -z "${MONGO_ADMIN_URI:-}" ]]; then
    require_non_empty MONGO_ADMIN_USER "${MONGO_ADMIN_USER:-}"
    require_non_empty MONGO_ADMIN_PASSWORD "${MONGO_ADMIN_PASSWORD:-}"
  fi
}
mongo_run() {
  require_cmd mongosh
  wait_k8s_pods_ready
  local folder
  folder=$(mktemp -d)
  # Payload is a private JSON literal in a file, never shell/JS interpolation or argv.
  ACTION="$ACTION" python3 -B "$ROOT_DIR/lib/mongo_script.py" > "$folder/run.js" || return 1
  if ! timeout 120s mongosh --nodb --quiet --file "$folder/run.js" > "$folder/client.log" 2>&1; then
    log "MongoDB failed; private evidence retained: $folder"
    return 1
  fi
  rm -rf -- "$folder"
  if [[ "$ACTION" == deprovision ]]; then
    APP_DB_URI=""
  else
    APP_DB_URI=$(python3 -B "$ROOT_DIR/lib/mongo_script.py" --uri)
  fi
}
mongo_provision() { mongo_run; }
mongo_deprovision() { mongo_run; }
