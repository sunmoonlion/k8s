#!/usr/bin/env bash
# register-client.sh
# 向 auth-app-backend 数据库注册新的 OAuth 客户端。
# 依赖：node（用于 argon2 hash），psql 或 node pg
#
# 用法：
#   APP_NAME=myapp \
#   CLIENT_ID=myapp-bff \
#   CLIENT_SECRET=your-secret-here \
#   REDIRECT_URI=https://myapp.example.com/auth/callback \
#   DB_URL=postgresql://user:pass@host:port/auth_db \
#   bash register-client.sh
#
# 可选变量：
#   SCOPES         默认 "openid profile email"
#   GRANT_TYPES    默认 "authorization_code refresh_token"
#   ENABLED        默认 true

set -euo pipefail

: "${APP_NAME:?APP_NAME is required}"
: "${CLIENT_ID:?CLIENT_ID is required}"
: "${CLIENT_SECRET:?CLIENT_SECRET is required}"
: "${REDIRECT_URI:?REDIRECT_URI is required}"
: "${DB_URL:?DB_URL is required}"

SCOPES="${SCOPES:-openid profile email}"
GRANT_TYPES="${GRANT_TYPES:-authorization_code refresh_token}"
ENABLED="${ENABLED:-true}"

echo "▶ Hashing client_secret with argon2..."

# 用 node + argon2 生成 hash（与 auth-app-backend 保持一致）
HASHED_SECRET=$(node -e "
const argon2 = require('$(dirname "$0")/../../../auth-app-backend/node_modules/argon2');
argon2.hash('${CLIENT_SECRET}').then(h => { process.stdout.write(h); }).catch(e => { process.stderr.write(e.message); process.exit(1); });
" 2>&1)

if [ $? -ne 0 ]; then
  echo "✗ Failed to hash secret. Make sure auth-app-backend node_modules is available."
  echo "  Fallback: manually insert with argon2 hash in auth-app DB."
  exit 1
fi

echo "▶ Inserting OAuth client into database..."

node -e "
const { Client } = require('pg');
const client = new Client({ connectionString: '${DB_URL}' });
client.connect().then(async () => {
  const now = new Date().toISOString();
  await client.query(\`
    INSERT INTO \"OAuthClient\" (
      \"clientId\",
      \"clientSecret\",
      \"name\",
      \"redirectUris\",
      \"scopes\",
      \"grantTypes\",
      \"enabled\",
      \"createdAt\",
      \"updatedAt\"
    ) VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9)
    ON CONFLICT (\"clientId\") DO UPDATE SET
      \"clientSecret\" = EXCLUDED.\"clientSecret\",
      \"redirectUris\" = EXCLUDED.\"redirectUris\",
      \"updatedAt\" = EXCLUDED.\"updatedAt\"
  \`, [
    '${CLIENT_ID}',
    '${HASHED_SECRET}',
    '${APP_NAME}',
    '${REDIRECT_URI}',
    '${SCOPES}',
    '${GRANT_TYPES}',
    ${ENABLED},
    now,
    now,
  ]);
  console.log('✓ Client registered: ${CLIENT_ID}');
  await client.end();
}).catch(e => { console.error('✗', e.message); process.exit(1); });
"

echo ""
echo "Done. Summary:"
echo "  client_id     : ${CLIENT_ID}"
echo "  redirect_uri  : ${REDIRECT_URI}"
echo "  scopes        : ${SCOPES}"
echo "  grant_types   : ${GRANT_TYPES}"
echo ""
echo "Next: set AUTH_CLIENT_ID=${CLIENT_ID} and AUTH_CLIENT_SECRET=<plaintext> in your app's .env"
