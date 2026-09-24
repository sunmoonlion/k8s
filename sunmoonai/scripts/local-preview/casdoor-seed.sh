#!/bin/sh
# 照 app-platform/auth-app/casdoor/deploy-casdoor/post-deploy-setup.sh 的 SQL 种：组织 sunmoonai、两个 application、一个演示用户。幂等。
# 与平台脚本的差别：Casdoor 3.42 的 application 要有 signin_methods（含 Password）与 enable_password，否则密码登录被拒；这里从 app-built-in 抄。
set -eu
psql_() { psql -v ON_ERROR_STOP=1 -h postgres -U casdoor -d casdoor -q "$@"; }
for i in $(seq 1 60); do psql_ -c "select 1 from application limit 1" >/dev/null 2>&1 && break; sleep 2; done
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
psql_ <<SQL
INSERT INTO organization (owner, name, created_time, display_name, default_application, password_type, country_codes, init_score, is_profile_public, languages)
VALUES ('admin', 'sunmoonai', '$now', 'SunMoon AI', 'sunmoonai-investment-web', 'plain', '["CN"]', 2000, false, '["en","zh"]')
ON CONFLICT (owner, name) DO UPDATE SET default_application = EXCLUDED.default_application, password_type = EXCLUDED.password_type, languages = EXCLUDED.languages;

INSERT INTO application (owner, name, created_time, display_name, client_id, client_secret, redirect_uris, cert, grant_types, organization, enable_sign_up, token_format, expire_in_hours, refresh_expire_in_hours, enable_password, signin_methods, signin_items, signup_items)
SELECT 'admin', 'sunmoonai-investment-web', '$now', 'SunMoon Investment Web', '$WEB_CLIENT_ID', '$WEB_CLIENT_SECRET', '["http://localhost:3000/api/auth/web/callback"]', 'cert-built-in', '["authorization_code"]', 'sunmoonai', false, 'JWT', 168, 336, true, b.signin_methods, b.signin_items, b.signup_items
FROM application b WHERE b.owner = 'admin' AND b.name = 'app-built-in'
ON CONFLICT (owner, name) DO UPDATE SET client_id = EXCLUDED.client_id, client_secret = EXCLUDED.client_secret, redirect_uris = EXCLUDED.redirect_uris, grant_types = EXCLUDED.grant_types, enable_password = EXCLUDED.enable_password, signin_methods = EXCLUDED.signin_methods, signin_items = EXCLUDED.signin_items, signup_items = EXCLUDED.signup_items;

INSERT INTO application (owner, name, created_time, display_name, client_id, client_secret, redirect_uris, cert, grant_types, organization, enable_sign_up, token_format, expire_in_hours, refresh_expire_in_hours, enable_password, signin_methods, signin_items, signup_items)
SELECT 'admin', 'sunmoonai-investment-admin', '$now', 'SunMoon Investment Admin', '$ADMIN_CLIENT_ID', '$ADMIN_CLIENT_SECRET', '["http://localhost:3000/api/auth/admin/callback"]', 'cert-built-in', '["authorization_code"]', 'sunmoonai', false, 'JWT', 168, 336, true, b.signin_methods, b.signin_items, b.signup_items
FROM application b WHERE b.owner = 'admin' AND b.name = 'app-built-in'
ON CONFLICT (owner, name) DO UPDATE SET client_id = EXCLUDED.client_id, client_secret = EXCLUDED.client_secret, redirect_uris = EXCLUDED.redirect_uris, enable_password = EXCLUDED.enable_password, signin_methods = EXCLUDED.signin_methods;

INSERT INTO "user" (owner, name, created_time, updated_time, id, type, password, password_salt, display_name, avatar, email, phone, score, karma, ranking, is_default_avatar, is_online, is_admin, is_forbidden, is_deleted, signup_application, properties, address, created_ip, signin_wrong_times)
VALUES ('sunmoonai', '$DEMO_USER', '$now', '$now', gen_random_uuid()::text, 'normal-user', '$DEMO_PASSWORD', '', '$DEMO_USER', 'https://cdn.casbin.org/img/casbin.svg', '$DEMO_USER@sunmoonai.local', '', 2000, 0, 1, false, false, false, false, false, 'sunmoonai-investment-web', '{}', '[]', '127.0.0.1', 0)
ON CONFLICT (owner, name) DO UPDATE SET password = EXCLUDED.password, updated_time = EXCLUDED.updated_time, signup_application = EXCLUDED.signup_application;
SQL
echo "casdoor seeded: org sunmoonai, user $DEMO_USER, app sunmoonai-investment-web"
