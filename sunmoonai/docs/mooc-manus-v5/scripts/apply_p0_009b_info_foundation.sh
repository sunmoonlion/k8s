#!/usr/bin/env bash
# Historical P0-009B overlay implementation. It is intentionally retired:
# copying whole legacy trees also copied .env files and generated binaries.

set -euo pipefail

echo "ERROR: retired unsafe one-shot overlay; use verify_p0_009e_convergence.py for freeze-tag clean-room replay" >&2
exit 64

TAG_TEMPLATE_RELEASE="p0-008b-b6-unified-20260729"
TPL_ADMIN_FE="/home/zymun/tpl-app/tpl-admin-frontend"
TPL_ADMIN_BE="/home/zymun/tpl-app/tpl-admin-backend"
TPL_WEB_FE="/home/zymun/tpl-app/tpl-web-frontend"
TPL_WEB_BE="/home/zymun/tpl-app/tpl-web-backend"

INFO_ADMIN_FE="/home/zymun/info-app/info-admin-frontend"
INFO_ADMIN_BE="/home/zymun/info-app/info-admin-backend"
INFO_WEB_FE="/home/zymun/info-app/info-web-frontend"
INFO_WEB_BE="/home/zymun/info-app/info-web-backend"

ADMIN_FE_COMMIT="fb69795b04e0b888a2917c3936f7f80aeac79cc9"
ADMIN_BE_COMMIT="69e634b8e5b06da9d1dcd01c9b1350e0571d74bd"
WEB_FE_COMMIT="1db9377d38dac5510331149d9122f8d375d83fe3"
WEB_BE_COMMIT="289f2c46410e0aa2891fdf3da28242ceb1a33bdb"

assert_commit() {
  local repo="$1" commit="$2"
  [[ "$(git -C "$repo" rev-parse HEAD)" == "$commit" ]] || {
    printf 'template %s HEAD is not frozen commit %s\n' "$repo" "$commit" >&2
    exit 1
  }
}

assert_commit "$TPL_ADMIN_FE" "$ADMIN_FE_COMMIT"
assert_commit "$TPL_ADMIN_BE" "$ADMIN_BE_COMMIT"
assert_commit "$TPL_WEB_FE" "$WEB_FE_COMMIT"
assert_commit "$TPL_WEB_BE" "$WEB_BE_COMMIT"

archive_dir() {
  local module_root="$1"
  local dest="$module_root/docs/p0-009b-domain-keep"
  mkdir -p "$dest"
  printf '%s\n' "$dest"
}

printf 'P0-009B_STAGE=web-frontend-overlay\n'
KEEP_WEB_FE="$(archive_dir "$INFO_WEB_FE")"
rm -rf "$KEEP_WEB_FE/pre-overlay-app"
mkdir -p "$KEEP_WEB_FE/pre-overlay-app"
# preserve branding/env snippets
[[ -f "$INFO_WEB_FE/app/messages/zh-CN.json" ]] && cp "$INFO_WEB_FE/app/messages/zh-CN.json" "$KEEP_WEB_FE/"
[[ -f "$INFO_WEB_FE/app/messages/en.json" ]] && cp "$INFO_WEB_FE/app/messages/en.json" "$KEEP_WEB_FE/"
[[ -f "$INFO_WEB_FE/app/.env.local" ]] && cp "$INFO_WEB_FE/app/.env.local" "$KEEP_WEB_FE/"
rsync -a --delete \
  --exclude node_modules --exclude .next --exclude dist --exclude test-results \
  --exclude .env.local --exclude .env \
  "$TPL_WEB_FE/app/" "$INFO_WEB_FE/app/"
# restore info package identity
python3 - <<'PY'
import json
from pathlib import Path
pkg=Path('/home/zymun/info-app/info-web-frontend/app/package.json')
data=json.loads(pkg.read_text())
data['name']='info-web-frontend'
pkg.write_text(json.dumps(data, indent=2, ensure_ascii=False)+'\n')
# branding messages
for locale, welcome in [('zh-CN.json','欢迎使用 Info'), ('en.json','Welcome to Info')]:
  path=Path('/home/zymun/info-app/info-web-frontend/app/messages')/locale
  msg=json.loads(path.read_text())
  msg.setdefault('Dashboard',{})
  if 'dashboardWelcome' in msg.get('Dashboard',{}):
    msg['Dashboard']['dashboardWelcome']=welcome
  # common Index/Home keys vary; set AppName-like fields when present
  for section in msg:
    if isinstance(msg[section], dict):
      if 'appName' in msg[section]:
        msg[section]['appName']='Info'
      if 'title' in msg[section] and section in ('Index','Home','Metadata'):
        if 'tpl' in str(msg[section]['title']).lower() or 'template' in str(msg[section]['title']).lower():
          msg[section]['title']='Info'
  path.write_text(json.dumps(msg, indent=2, ensure_ascii=False)+'\n')
PY
# mybuild image name
if [[ -f "$INFO_WEB_FE/mybuild/build.conf" ]]; then
  sed -i 's/tpl-web-frontend/info-web-frontend/g' "$INFO_WEB_FE/mybuild/build.conf" || true
fi
# copy standalone mybuild pieces from template if missing prepare scripts
rsync -a "$TPL_WEB_FE/mybuild/" "$INFO_WEB_FE/mybuild/" \
  --exclude build.conf --exclude '*.log'
# rewrite build.conf image vars if template overwrote
cat > "$INFO_WEB_FE/mybuild/build.conf" <<'EOF'
# Info Web Frontend image build config (P0-009B)
WEB_FRONTEND_IMAGE="info-web-frontend"
WEB_FRONTEND_TAG="p0-009b-info-candidate-20260729"
SOURCE_DIR="app"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CONTAINER_RUNTIME="docker"
NERDCTL_NAMESPACE="k8s.io"
INFO_SSR_IMAGE="info-web-frontend"
INFO_SSR_TAG="p0-009b-info-candidate-20260729"
WEB_FRONTEND_IMAGE_REGISTRY="${WEB_FRONTEND_IMAGE_REGISTRY:-harbor.sunmoonai.com}"
WEB_FRONTEND_IMAGE_PROJECT="${WEB_FRONTEND_IMAGE_PROJECT:-app-images}"
REGISTRY="${REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PUSH_IMAGES_AFTER_BUILD="${PUSH_IMAGES_AFTER_BUILD:-false}"
EOF

printf 'P0-009B_STAGE=web-backend-overlay\n'
KEEP_WEB_BE="$(archive_dir "$INFO_WEB_BE")"
rm -rf "$KEEP_WEB_BE/pre-overlay-nest"
mkdir -p "$KEEP_WEB_BE/pre-overlay-nest"
# archive nest tree for domain reference (not runtime)
rsync -a --delete \
  --exclude node_modules --exclude dist --exclude .git \
  "$INFO_WEB_BE/app/" "$KEEP_WEB_BE/pre-overlay-nest/app/" || true
[[ -d "$INFO_WEB_BE/mybuild" ]] && rsync -a "$INFO_WEB_BE/mybuild/" "$KEEP_WEB_BE/pre-overlay-nest/mybuild/" || true
# replace with FastAPI web template
rm -rf "$INFO_WEB_BE/app"
mkdir -p "$INFO_WEB_BE/app"
rsync -a --delete \
  --exclude .venv --exclude __pycache__ --exclude .env --exclude .env.* \
  --exclude .pytest_cache --exclude htmlcov \
  "$TPL_WEB_BE/app/" "$INFO_WEB_BE/app/"
rsync -a "$TPL_WEB_BE/mybuild/" "$INFO_WEB_BE/mybuild/"
# root files
for f in .dockerignore .gitignore README.md; do
  [[ -f "$TPL_WEB_BE/$f" ]] && cp "$TPL_WEB_BE/$f" "$INFO_WEB_BE/$f"
done
# instantiate info identity defaults in config via sed on service defaults after copy
python3 - <<'PY'
from pathlib import Path
cfg=Path('/home/zymun/info-app/info-web-backend/app/core/config.py')
text=cfg.read_text()
repls={
  'service_name: str = "tpl-web-backend"': 'service_name: str = "info-web-backend"',
  'app_slug: str = "tpl"': 'app_slug: str = "info"',
  'auth_policy_version: str = "tpl-web-v1"': 'auth_policy_version: str = "info-web-v1"',
  'casdoor_application: str = "sunmoonai-tpl-web"': 'casdoor_application: str = "sunmoonai-info-web"',
}
for a,b in repls.items():
  if a not in text:
    raise SystemExit(f'missing config anchor: {a}')
  text=text.replace(a,b,1)
# cookie / redis prefix patterns often derived from app_slug; leave validators intact
cfg.write_text(text)
# pyproject name
py=Path('/home/zymun/info-app/info-web-backend/app/pyproject.toml')
py.write_text(py.read_text().replace('name = "tpl-web-backend"','name = "info-web-backend"',1))
Path('/home/zymun/info-app/info-web-backend/mybuild/build.conf').write_text('''# Info Web Backend (FastAPI) P0-009B
WEB_BACKEND_IMAGE="info-web-backend"
WEB_BACKEND_TAG="p0-009b-info-candidate-20260729"
SOURCE_DIR="app"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CONTAINER_RUNTIME="docker"
NERDCTL_NAMESPACE="k8s.io"
REGISTRY="${REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PUSH_IMAGES_AFTER_BUILD="${PUSH_IMAGES_AFTER_BUILD:-false}"
''')
print('web-backend instantiated')
PY

printf 'P0-009B_STAGE=admin-frontend-overlay\n'
KEEP_ADMIN_FE="$(archive_dir "$INFO_ADMIN_FE")"
mkdir -p "$KEEP_ADMIN_FE/react-router-domain"
# archive domain sources
for f in \
  app/routes/info-crawl.tsx \
  app/lib/info-api.ts \
  app/lib/navigation.ts \
  app/lib/i18n.tsx
do
  [[ -f "$INFO_ADMIN_FE/$f" ]] && mkdir -p "$KEEP_ADMIN_FE/react-router-domain/$(dirname "$f")" && cp "$INFO_ADMIN_FE/$f" "$KEEP_ADMIN_FE/react-router-domain/$f"
done
# replace app tree with Next Admin template
rm -rf "$INFO_ADMIN_FE/app"
mkdir -p "$INFO_ADMIN_FE/app"
rsync -a --delete \
  --exclude node_modules --exclude .next --exclude dist --exclude test-results \
  --exclude .env.local --exclude .env \
  "$TPL_ADMIN_FE/app/" "$INFO_ADMIN_FE/app/"
rsync -a "$TPL_ADMIN_FE/mybuild/" "$INFO_ADMIN_FE/mybuild/"
python3 - <<'PY'
import json
from pathlib import Path
pkg=Path('/home/zymun/info-app/info-admin-frontend/app/package.json')
data=json.loads(pkg.read_text())
data['name']='info-admin-frontend'
pkg.write_text(json.dumps(data, indent=2, ensure_ascii=False)+'\n')
for locale in ['zh-CN.json','en.json']:
  path=Path('/home/zymun/info-app/info-admin-frontend/app/messages')/locale
  msg=json.loads(path.read_text())
  # inject info crawl label keys
  for section, key, value in [
    ('Navigation','infoCrawl','资讯采集' if locale.startswith('zh') else 'Info crawl'),
    ('InfoCrawl','title','资讯采集' if locale.startswith('zh') else 'Info crawl'),
    ('InfoCrawl','description','Info Admin 领域采集与分发控制台' if locale.startswith('zh') else 'Info Admin crawl and distribution console'),
  ]:
    msg.setdefault(section,{})
    if isinstance(msg[section], dict):
      msg[section][key]=value
  path.write_text(json.dumps(msg, indent=2, ensure_ascii=False)+'\n')
Path('/home/zymun/info-app/info-admin-frontend/mybuild/build.conf').write_text('''# Info Admin Frontend (Next) P0-009B
ADMIN_FRONTEND_IMAGE="info-admin-frontend"
ADMIN_FRONTEND_TAG="p0-009b-info-candidate-20260729"
SOURCE_DIR="app"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CONTAINER_RUNTIME="docker"
NERDCTL_NAMESPACE="k8s.io"
REGISTRY="${REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PUSH_IMAGES_AFTER_BUILD="${PUSH_IMAGES_AFTER_BUILD:-false}"
''')
print('admin-frontend overlaid')
PY

printf 'P0-009B_STAGE=admin-backend-kernel-sync\n'
KEEP_ADMIN_BE="$(archive_dir "$INFO_ADMIN_BE")"
mkdir -p "$KEEP_ADMIN_BE/pre-kernel"
# sync selected kernel files from frozen admin backend template
KERNEL_FILES=(
  app/main.py
  app/domain/security/principal.py
  app/interfaces/errors/exception_handlers.py
  app/application/services/auth_service.py
  app/interfaces/endpoints/auth_routes.py
  app/infrastructure/security/oidc.py
  app/infrastructure/storage/postgres.py
  app/infrastructure/storage/redis.py
  app/infrastructure/logging/logging.py
  app/infrastructure/messaging/celery_producer.py
  # NOTE: after sync, re-attach Info domain dispatch_* methods onto CeleryProducer.
  app/infrastructure/models/auth.py
  app/infrastructure/models/base.py
  tests/test_kernel_invariants.py
  tests/test_auth_routes_security.py
  tests/test_auth_service.py
  tests/test_oidc_security.py
  tests/test_config_security.py
)
for rel in "${KERNEL_FILES[@]}"; do
  src="$TPL_ADMIN_BE/app/$rel"
  dst="$INFO_ADMIN_BE/app/$rel"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]]; then
      mkdir -p "$KEEP_ADMIN_BE/pre-kernel/$(dirname "$rel")"
      cp "$dst" "$KEEP_ADMIN_BE/pre-kernel/$rel"
    fi
    cp "$src" "$dst"
  fi
done
# merge config carefully: copy tpl config then reinstate info service identity defaults
cp "$INFO_ADMIN_BE/app/core/config.py" "$KEEP_ADMIN_BE/pre-kernel/core-config.py"
cp "$TPL_ADMIN_BE/app/core/config.py" "$INFO_ADMIN_BE/app/core/config.py"
python3 - <<'PY'
from pathlib import Path
cfg=Path('/home/zymun/info-app/info-admin-backend/app/core/config.py')
text=cfg.read_text()
repls={
  'service_name: str = "tpl-admin-backend"': 'service_name: str = "info-admin-backend"',
  'app_slug: str = "tpl"': 'app_slug: str = "info"',
  'auth_policy_version: str = "tpl-admin-v1"': 'auth_policy_version: str = "info-admin-v1"',
  'casdoor_application: str = "sunmoonai-tpl-admin"': 'casdoor_application: str = "sunmoonai-info-admin"',
}
for a,b in repls.items():
  if a in text:
    text=text.replace(a,b,1)
  else:
    print('WARN missing admin config anchor', a)
cfg.write_text(text)
print('admin-backend kernel synced')
PY

printf 'P0-009B_STAGE=overlay-complete template_release=%s\n' "$TAG_TEMPLATE_RELEASE"
