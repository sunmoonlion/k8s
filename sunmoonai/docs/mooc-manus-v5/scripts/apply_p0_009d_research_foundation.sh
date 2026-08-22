#!/usr/bin/env bash
# Historical P0-009D overlay implementation. It is intentionally retired:
# copying whole legacy trees also copied .env files and generated binaries.

set -euo pipefail

echo "ERROR: retired unsafe one-shot overlay; use verify_p0_009e_convergence.py for freeze-tag clean-room replay" >&2
exit 64

TAG_TEMPLATE_RELEASE="p0-008b-b6-unified-20260729"
CANDIDATE_TAG="p0-009d-research-candidate-20260729"

TPL_ADMIN_FE="/home/zymun/master/tpl-app/tpl-admin-frontend"
TPL_ADMIN_BE="/home/zymun/master/tpl-app/tpl-admin-backend"
TPL_WEB_FE="/home/zymun/master/tpl-app/tpl-web-frontend"
TPL_WEB_BE="/home/zymun/master/tpl-app/tpl-web-backend"

RS_ADMIN_FE="/home/zymun/research-app/research-admin-frontend"
RS_ADMIN_BE="/home/zymun/research-app/research-admin-backend"
RS_WEB_FE="/home/zymun/research-app/research-web-frontend"
RS_WEB_BE="/home/zymun/research-app/research-web-backend"

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
  local dest="$module_root/docs/p0-009d-domain-keep"
  mkdir -p "$dest"
  printf '%s\n' "$dest"
}

printf 'P0-009D_STAGE=web-frontend-overlay\n'
KEEP_WEB_FE="$(archive_dir "$RS_WEB_FE")"
rm -rf "$KEEP_WEB_FE/pre-overlay-app"
mkdir -p "$KEEP_WEB_FE/pre-overlay-app"
rsync -a --delete \
  --exclude node_modules --exclude .next --exclude dist --exclude test-results \
  --exclude .env.local --exclude .env \
  "$RS_WEB_FE/app/" "$KEEP_WEB_FE/pre-overlay-app/" || true
rsync -a --delete \
  --exclude node_modules --exclude .next --exclude dist --exclude test-results \
  --exclude .env.local --exclude .env \
  "$TPL_WEB_FE/app/" "$RS_WEB_FE/app/"
python3 - <<'PY'
import json
from pathlib import Path
pkg=Path('/home/zymun/research-app/research-web-frontend/app/package.json')
data=json.loads(pkg.read_text())
data['name']='research-web-frontend'
pkg.write_text(json.dumps(data, indent=2, ensure_ascii=False)+'\n')
for locale, welcome in [('zh-CN.json','欢迎使用 Research'), ('en.json','Welcome to Research')]:
  path=Path('/home/zymun/research-app/research-web-frontend/app/messages')/locale
  msg=json.loads(path.read_text())
  msg.setdefault('Dashboard',{})
  if 'dashboardWelcome' in msg.get('Dashboard',{}):
    msg['Dashboard']['dashboardWelcome']=welcome
  for section in msg:
    if isinstance(msg[section], dict):
      if 'appName' in msg[section]:
        msg[section]['appName']='Research'
      if 'title' in msg[section] and section in ('Index','Home','Metadata'):
        if 'tpl' in str(msg[section]['title']).lower() or 'template' in str(msg[section]['title']).lower():
          msg[section]['title']='Research'
  path.write_text(json.dumps(msg, indent=2, ensure_ascii=False)+'\n')
PY
rsync -a "$TPL_WEB_FE/mybuild/" "$RS_WEB_FE/mybuild/" \
  --exclude build.conf --exclude '*.log'
cat > "$RS_WEB_FE/mybuild/build.conf" <<EOF
# Research Web Frontend image build config (P0-009D)
WEB_FRONTEND_IMAGE="research-web-frontend"
WEB_FRONTEND_TAG="${CANDIDATE_TAG}"
SOURCE_DIR="app"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CONTAINER_RUNTIME="docker"
NERDCTL_NAMESPACE="k8s.io"
RESEARCH_SSR_IMAGE="research-web-frontend"
RESEARCH_SSR_TAG="${CANDIDATE_TAG}"
TPL_SSR_IMAGE="research-web-frontend"
TPL_SSR_TAG="${CANDIDATE_TAG}"
WEB_FRONTEND_IMAGE_REGISTRY="\${WEB_FRONTEND_IMAGE_REGISTRY:-harbor.sunmoonai.com}"
WEB_FRONTEND_IMAGE_PROJECT="\${WEB_FRONTEND_IMAGE_PROJECT:-app-images}"
REGISTRY="\${REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PUSH_IMAGES_AFTER_BUILD="\${PUSH_IMAGES_AFTER_BUILD:-false}"
EOF

printf 'P0-009D_STAGE=web-backend-overlay\n'
KEEP_WEB_BE="$(archive_dir "$RS_WEB_BE")"
rm -rf "$KEEP_WEB_BE/pre-overlay-nest"
mkdir -p "$KEEP_WEB_BE/pre-overlay-nest"
rsync -a --delete \
  --exclude node_modules --exclude dist --exclude .git \
  "$RS_WEB_BE/app/" "$KEEP_WEB_BE/pre-overlay-nest/app/" || true
[[ -d "$RS_WEB_BE/mybuild" ]] && rsync -a "$RS_WEB_BE/mybuild/" "$KEEP_WEB_BE/pre-overlay-nest/mybuild/" || true
rm -rf "$RS_WEB_BE/app"
mkdir -p "$RS_WEB_BE/app"
rsync -a --delete \
  --exclude .venv --exclude __pycache__ --exclude .env --exclude .env.* \
  --exclude .pytest_cache --exclude htmlcov \
  "$TPL_WEB_BE/app/" "$RS_WEB_BE/app/"
rsync -a "$TPL_WEB_BE/mybuild/" "$RS_WEB_BE/mybuild/"
for f in .dockerignore .gitignore README.md; do
  [[ -f "$TPL_WEB_BE/$f" ]] && cp "$TPL_WEB_BE/$f" "$RS_WEB_BE/$f"
done
python3 - <<'PY'
from pathlib import Path
cfg=Path('/home/zymun/research-app/research-web-backend/app/core/config.py')
text=cfg.read_text()
repls={
  'service_name: str = "tpl-web-backend"': 'service_name: str = "research-web-backend"',
  'app_slug: str = "tpl"': 'app_slug: str = "research"',
  'auth_policy_version: str = "tpl-web-v1"': 'auth_policy_version: str = "research-web-v1"',
  'casdoor_application: str = "sunmoonai-tpl-web"': 'casdoor_application: str = "sunmoonai-research-web"',
}
for a,b in repls.items():
  if a not in text:
    raise SystemExit(f'missing config anchor: {a}')
  text=text.replace(a,b,1)
cfg.write_text(text)
py=Path('/home/zymun/research-app/research-web-backend/app/pyproject.toml')
py.write_text(py.read_text().replace('name = "tpl-web-backend"','name = "research-web-backend"',1))
print('web-backend instantiated')
PY
cat > "$RS_WEB_BE/mybuild/build.conf" <<EOF
# Research Web Backend (FastAPI) P0-009D
WEB_BACKEND_IMAGE="research-web-backend"
WEB_BACKEND_TAG="${CANDIDATE_TAG}"
SOURCE_DIR="app"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CONTAINER_RUNTIME="docker"
NERDCTL_NAMESPACE="k8s.io"
REGISTRY="\${REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PUSH_IMAGES_AFTER_BUILD="\${PUSH_IMAGES_AFTER_BUILD:-false}"
EOF

printf 'P0-009D_STAGE=admin-frontend-overlay\n'
KEEP_ADMIN_FE="$(archive_dir "$RS_ADMIN_FE")"
rm -rf "$KEEP_ADMIN_FE/pre-overlay-vue"
mkdir -p "$KEEP_ADMIN_FE/pre-overlay-vue"
# Archive entire Vue tree (no Dataset/Ingestion/Retrieval pages existed to reattach).
rsync -a --delete \
  --exclude node_modules --exclude dist --exclude .git --exclude docs \
  "$RS_ADMIN_FE/" "$KEEP_ADMIN_FE/pre-overlay-vue/" \
  --exclude 'docs' || true
rm -rf "$RS_ADMIN_FE/app"
mkdir -p "$RS_ADMIN_FE/app"
rsync -a --delete \
  --exclude node_modules --exclude .next --exclude dist --exclude test-results \
  --exclude .env.local --exclude .env \
  "$TPL_ADMIN_FE/app/" "$RS_ADMIN_FE/app/"
rsync -a "$TPL_ADMIN_FE/mybuild/" "$RS_ADMIN_FE/mybuild/"
# Drop Vue root leftovers that conflict with Next module layout (keep docs/CLAUDE/git)
python3 - <<'PY'
from pathlib import Path
root=Path('/home/zymun/research-app/research-admin-frontend')
keep={'app','mybuild','docs','.git','CLAUDE.md','README.md','LICENSE','.gitignore','.dockerignore'}
for child in list(root.iterdir()):
  if child.name in keep or child.name.startswith('.'):
    continue
  # leave archived Vue sources only under docs/p0-009d-domain-keep
  if child.is_dir():
    import shutil
    shutil.rmtree(child, ignore_errors=True)
  else:
    child.unlink(missing_ok=True)
print('admin-frontend vue leftovers cleared')
PY
python3 - <<'PY'
import json
from pathlib import Path
pkg=Path('/home/zymun/research-app/research-admin-frontend/app/package.json')
data=json.loads(pkg.read_text())
data['name']='research-admin-frontend'
pkg.write_text(json.dumps(data, indent=2, ensure_ascii=False)+'\n')
for locale in ['zh-CN.json','en.json']:
  path=Path('/home/zymun/research-app/research-admin-frontend/app/messages')/locale
  msg=json.loads(path.read_text())
  zh=locale.startswith('zh')
  for section, key, value in [
    ('Navigation','researchIngestions','运行时治理' if zh else 'Research ingestions'),
    ('ResearchIngestions','title','运行时治理' if zh else 'Research ingestions'),
    ('ResearchIngestions','description',
     'Research Admin Dataset/Ingestion 控制台（最小域壳）' if zh
     else 'Research Admin Dataset/Ingestion control surface (minimal shell)'),
  ]:
    msg.setdefault(section,{})
    if isinstance(msg[section], dict):
      msg[section][key]=value
  path.write_text(json.dumps(msg, indent=2, ensure_ascii=False)+'\n')
print('admin-frontend overlaid')
PY
cat > "$RS_ADMIN_FE/mybuild/build.conf" <<EOF
# Research Admin Frontend (Next) P0-009D
ADMIN_FRONTEND_IMAGE="research-admin-frontend"
ADMIN_FRONTEND_TAG="${CANDIDATE_TAG}"
SOURCE_DIR="app"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
CONTAINER_RUNTIME="docker"
NERDCTL_NAMESPACE="k8s.io"
TPL_SSR_IMAGE="research-admin-frontend"
TPL_SSR_TAG="${CANDIDATE_TAG}"
REGISTRY="\${REGISTRY:-harbor.sunmoonai.com:30443/k8s-images}"
PUSH_IMAGES_AFTER_BUILD="\${PUSH_IMAGES_AFTER_BUILD:-false}"
EOF

printf 'P0-009D_STAGE=admin-backend-kernel-sync\n'
KEEP_ADMIN_BE="$(archive_dir "$RS_ADMIN_BE")"
mkdir -p "$KEEP_ADMIN_BE/pre-kernel"
KERNEL_FILES=(
  app/main.py
  app/domain/security/principal.py
  app/interfaces/errors/exception_handlers.py
  app/application/services/auth_service.py
  app/interfaces/endpoints/auth_routes.py
  app/interfaces/endpoints/tasks_routes.py
  app/infrastructure/security/oidc.py
  app/infrastructure/storage/postgres.py
  app/infrastructure/storage/redis.py
  app/infrastructure/logging/logging.py
  app/infrastructure/messaging/celery_producer.py
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
  dst="$RS_ADMIN_BE/app/$rel"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]]; then
      mkdir -p "$KEEP_ADMIN_BE/pre-kernel/$(dirname "$rel")"
      cp "$dst" "$KEEP_ADMIN_BE/pre-kernel/$rel"
    fi
    cp "$src" "$dst"
  fi
done
cp "$RS_ADMIN_BE/app/core/config.py" "$KEEP_ADMIN_BE/pre-kernel/core-config.py"
cp "$TPL_ADMIN_BE/app/core/config.py" "$RS_ADMIN_BE/app/core/config.py"
python3 - <<'PY'
from pathlib import Path
cfg=Path('/home/zymun/research-app/research-admin-backend/app/core/config.py')
text=cfg.read_text()
repls={
  'service_name: str = "tpl-admin-backend"': 'service_name: str = "research-admin-backend"',
  'app_slug: str = "tpl"': 'app_slug: str = "research"',
  'auth_policy_version: str = "tpl-admin-v1"': 'auth_policy_version: str = "research-admin-v1"',
  'casdoor_application: str = "sunmoonai-tpl-admin"': 'casdoor_application: str = "sunmoonai-research-admin"',
  'postgresql+asyncpg://tpl:tpl@localhost:5432/tpl': 'postgresql+asyncpg://research:research@localhost:5432/research',
  'default="tpl.admin.default"': 'default="research.admin.default"',
}
for a,b in repls.items():
  if a in text:
    text=text.replace(a,b,1)
  else:
    print('WARN missing admin config anchor', a)
cfg.write_text(text)
print('admin-backend kernel synced (identity only; domain fields still need stitch)')
PY

printf 'P0-009D_STAGE=overlay-complete template_release=%s candidate=%s\n' \
  "$TAG_TEMPLATE_RELEASE" "$CANDIDATE_TAG"
printf 'NEXT: run stitch_p0_009c_research_foundation.py\n'
