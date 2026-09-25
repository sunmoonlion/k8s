#!/bin/bash
# 自助注册（security.md「账号与注册」，所有者 2026-09-26 定）：只给一个应用开注册，三道闸——
#   邀请码必填、邮箱验证码、人机校验；手机号留接口（默认不收）。
#
# 由 post-deploy-setup.sh source，用它的 run_sql / sql_escape_single / log_*。也可单独 source 做测试。
# 按 Casdoor 3.42.0 源码核过的数据形状：
#   application.signup_items  JSON 数组，项名 "Invitation code"、"Email"（rule "Normal" = 发验证码）、"Phone"
#   application.providers     JSON 数组，Captcha 项 rule："None" 关 / "Dynamic" / "Always" / "Internet-Only"
#   provider（owner=admin）   Email 类，type "Default" = SMTP：client_id 用户名、client_secret 口令、
#                             client_id2 发信地址、client_secret2 发信人名、host/port/ssl_mode、title/content（%s = 验证码）
#   invitation（owner=组织）  code、quota、used_count、application、可选 email、state "Active"
#
# 邮件服务未配时注册**保持关闭**：邮箱要验证码，没有发信服务就注册不了，开着只会让用户卡在发码那一步。
#
# 配置（post-deploy-setup.local.conf，不进 git）：
#   SIGNUP_APP            开注册的应用名，如 sunmoonai-investment-web；空 = 不做本步
#   SIGNUP_ORG            该应用所属组织（默认 sunmoonai）
#   SIGNUP_CAPTCHA_RULE   Internet-Only（默认：公网来的一律要，内网与本机不要）/ Always / Dynamic / None
#   邮件（SMTP，腾讯云邮件推送与企业邮箱都是 SMTP，同一个接口）：
#   SIGNUP_SMTP_HOST      如 smtp.qcloudmail.com（腾讯云邮件推送）、smtp.exmail.qq.com（腾讯企业邮）
#   SIGNUP_SMTP_PORT      默认 465
#   SIGNUP_SMTP_SSL_MODE  Enable（默认，465）/ Auto / Disable
#   SIGNUP_SMTP_USER      SMTP 用户名
#   SIGNUP_SMTP_PASSWORD  SMTP 口令（从 Secret / 环境注入，不写进仓库）
#   SIGNUP_SMTP_FROM      发信地址（空 = 用 SIGNUP_SMTP_USER）
#   SIGNUP_SMTP_FROM_NAME 发信人名（默认 SunMoon AI）
#   SIGNUP_EMAIL_TITLE / SIGNUP_EMAIL_CONTENT  验证码邮件标题与正文（正文里 %s 换成验证码）
#   手机号（接口，默认关）：
#   SIGNUP_PHONE_ENABLED  true 时注册要填手机号并验证；需先在 Casdoor 建好短信提供方
#   SIGNUP_SMS_PROVIDER   短信提供方名（owner=admin）；PHONE_ENABLED=true 时必填
#   SIGNUP_CLOSE_BUILTIN  true（默认）：关掉 Casdoor 自带应用 app-built-in 的注册（它默认开着，
#                         任何人都能注册进 built-in 组织，也就是 Casdoor 自己的管理组织）
#   页面文字与品牌（注册页、登录页是 Casdoor 托管页，按下面这些渲染）：
#   SIGNUP_BRAND_TITLE    页面顶部标题，默认「SunMoon AI 投研」；没有图标时以这行字当标志
#   SIGNUP_LOGO_URL       标志图片地址（≤200 字符，Casdoor 的列上限）；空 = 用上面的文字标志
#   SIGNUP_FOOTER_HTML    页脚，默认「© SunMoon AI」（替掉 Powered by Casdoor）
#   首个邀请码（可选，之后的码在 Casdoor 后台发）：
#   SIGNUP_INVITATION_CODE / SIGNUP_INVITATION_QUOTA（默认 10）/ SIGNUP_INVITATION_EMAIL（绑定邮箱，可空）

SIGNUP_EMAIL_PROVIDER_NAME="provider_email_signup"

signup_json_str() { # JSON 字符串转义（只处理本脚本会遇到的字符）
    local s=${1//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '"%s"' "$s"
}

signup_items_json() { # $1 = true/false 手机号。顺序即页面顺序：邮箱与验证码 → 用户名 → 密码 → 邀请码
    local phone=$1
    cat <<EOF
[{"name":"ID","visible":false,"required":true,"prompted":false,"type":"","customCss":"","label":"","placeholder":"","options":[],"regex":"","rule":"Random"},
{"name":"Email","visible":true,"required":true,"prompted":false,"type":"","customCss":"","label":"","placeholder":"用来收验证码，也可以用它登录","options":[],"regex":"","rule":"Normal"},
{"name":"Phone","visible":$phone,"required":$phone,"prompted":false,"type":"","customCss":"","label":"","placeholder":"","options":[],"regex":"","rule":"Normal"},
{"name":"Username","visible":true,"required":true,"prompted":false,"type":"","customCss":"","label":"","placeholder":"登录用，字母、数字或下划线","options":[],"regex":"","rule":"None"},
{"name":"Display name","visible":false,"required":false,"prompted":false,"type":"","customCss":"","label":"","placeholder":"","options":[],"regex":"","rule":"None"},
{"name":"Password","visible":true,"required":true,"prompted":false,"type":"","customCss":"","label":"","placeholder":"至少 6 位","options":[],"regex":"","rule":"None"},
{"name":"Confirm password","visible":true,"required":true,"prompted":false,"type":"","customCss":"","label":"","placeholder":"再输一次","options":[],"regex":"","rule":"None"},
{"name":"Invitation code","visible":true,"required":true,"prompted":false,"type":"","customCss":"","label":"","placeholder":"没有邀请码？到首页申请","options":[],"regex":"","rule":"None"}]
EOF
}

apply_signup_branding() { # 应用的标题、标志、页脚；组织的语言顺序中文在前（Casdoor 取第一个为默认）
    local app=$1 org=$2
    local title=${SIGNUP_BRAND_TITLE:-SunMoon AI 投研}
    local logo=${SIGNUP_LOGO_URL:-}
    local footer=${SIGNUP_FOOTER_HTML:-<div style="text-align:center;color:#9ca3af;font-size:12px;padding:16px 0">© SunMoon AI</div>}
    [[ ${#logo} -le 200 ]] || { log_error "SIGNUP_LOGO_URL 超过 200 字符（Casdoor 的 logo 列上限），请用 https 地址"; return 1; }
    local css
    if [[ -z "$logo" ]]; then
        # 没有图标：藏掉 Casdoor 的标志图位（logo 列只收 200 字符的地址），在表单上方放一行文字标题
        # Casdoor 把 form_css 原样插进页面，要自带 <style>
        css="<style>.panel-logo{display:none}.login-form::before{content:\"${title//\"/}\";display:block;text-align:center;font-size:26px;font-weight:600;color:#1f2937;margin:12px 0 28px}.login-form .select-box{display:none}</style>"
    else
        css="<style>.login-form .select-box{display:none}</style>"
    fi
    local e_app e_org e_title e_logo e_footer e_css
    e_app=$(sql_escape_single "$app"); e_org=$(sql_escape_single "$org")
    e_title=$(sql_escape_single "$title"); e_logo=$(sql_escape_single "$logo"); e_footer=$(sql_escape_single "$footer")
    e_css=$(sql_escape_single "$css")
    run_sql "UPDATE application SET display_name = '$e_title', title = '$e_title', logo = '$e_logo', footer_html = '$e_footer',
        form_css = '$e_css' WHERE owner = 'admin' AND name = '$e_app';" >/dev/null || { log_error "应用品牌写入失败：$app"; return 1; }
    # 组织语言只留中文：Casdoor 3.42 的登录/注册页在组织只列一种语言时强制用它；列两种以上时显示切换器、
    #   且不认浏览器语言而退回英文（web/src/auth/LoginPage.js）。组织名给 info、knowledge 各应用共用，不改
    run_sql "UPDATE organization SET languages = '[\"zh\"]'
        WHERE owner = 'admin' AND name = '$e_org';" >/dev/null || { log_error "组织语言写入失败：$org"; return 1; }
    log_ok "页面品牌：标题「$title」，标志=$([[ -n "$logo" ]] && echo 图片 || echo 文字)，只用中文"
}

signup_provider_item() { # $1 名 $2 rule
    printf '{"owner":"","name":%s,"canSignUp":false,"canSignIn":false,"canUnlink":false,"bindingRule":null,"countryCodes":["All"],"prompted":false,"signupGroup":"","rule":%s,"provider":null}' \
        "$(signup_json_str "$1")" "$(signup_json_str "$2")"
}

signup_providers_json() { # $1 captcha rule $2 email provider 名或空 $3 sms provider 名或空
    local items=()
    items+=("$(signup_provider_item provider_captcha_default "$1")")
    if [[ -n "$2" ]]; then items+=("$(signup_provider_item "$2" All)"); fi
    if [[ -n "$3" ]]; then items+=("$(signup_provider_item "$3" All)"); fi
    local IFS=,
    printf '[%s]' "${items[*]}"
}

upsert_signup_email_provider() {
    local host=$SIGNUP_SMTP_HOST port=${SIGNUP_SMTP_PORT:-465} ssl=${SIGNUP_SMTP_SSL_MODE:-Enable}
    local user=$SIGNUP_SMTP_USER pass=${SIGNUP_SMTP_PASSWORD:-} from=${SIGNUP_SMTP_FROM:-$SIGNUP_SMTP_USER}
    local from_name=${SIGNUP_SMTP_FROM_NAME:-SunMoon AI}
    local title=${SIGNUP_EMAIL_TITLE:-SunMoon AI 注册验证码}
    local content=${SIGNUP_EMAIL_CONTENT:-你的注册验证码是 %s，5 分钟内有效。如果不是你本人操作，请忽略这封邮件。}
    [[ -n "$user" && -n "$pass" ]] || { log_error "邮件服务缺 SIGNUP_SMTP_USER / SIGNUP_SMTP_PASSWORD"; return 1; }
    [[ "$port" =~ ^[0-9]+$ ]] || { log_error "SIGNUP_SMTP_PORT 不是数字"; return 1; }
    [[ "$ssl" =~ ^(Enable|Auto|Disable)$ ]] || { log_error "SIGNUP_SMTP_SSL_MODE 只能 Enable/Auto/Disable"; return 1; }
    [[ "$content" == *%s* ]] || { log_error "SIGNUP_EMAIL_CONTENT 里要有 %s（验证码的位置）"; return 1; }
    local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local e_host e_user e_pass e_from e_from_name e_title e_content
    e_host=$(sql_escape_single "$host"); e_user=$(sql_escape_single "$user"); e_pass=$(sql_escape_single "$pass")
    e_from=$(sql_escape_single "$from"); e_from_name=$(sql_escape_single "$from_name")
    e_title=$(sql_escape_single "$title"); e_content=$(sql_escape_single "$content")
    run_sql "INSERT INTO provider (owner, name, created_time, display_name, category, type, client_id, client_secret, client_id2, client_secret2, host, port, ssl_mode, disable_ssl, title, content)
        VALUES ('admin', '$SIGNUP_EMAIL_PROVIDER_NAME', '$now', '注册验证码邮件', 'Email', 'Default', '$e_user', '$e_pass', '$e_from', '$e_from_name', '$e_host', $port, '$ssl', false, '$e_title', '$e_content')
        ON CONFLICT (owner, name) DO UPDATE SET category = EXCLUDED.category, type = EXCLUDED.type,
          client_id = EXCLUDED.client_id, client_secret = EXCLUDED.client_secret, client_id2 = EXCLUDED.client_id2,
          client_secret2 = EXCLUDED.client_secret2, host = EXCLUDED.host, port = EXCLUDED.port, ssl_mode = EXCLUDED.ssl_mode,
          disable_ssl = EXCLUDED.disable_ssl, title = EXCLUDED.title, content = EXCLUDED.content;" >/dev/null \
        || { log_error "邮件提供方写入失败"; return 1; }
    log_ok "邮件提供方就绪：$SIGNUP_EMAIL_PROVIDER_NAME（$host:$port，口令不显示）"
}

upsert_signup_invitation() { # 可选：首个邀请码
    local code=${SIGNUP_INVITATION_CODE:-}
    [[ -n "$code" ]] || return 0
    local quota=${SIGNUP_INVITATION_QUOTA:-10} email=${SIGNUP_INVITATION_EMAIL:-}
    [[ "$quota" =~ ^[0-9]+$ ]] || { log_error "SIGNUP_INVITATION_QUOTA 不是数字"; return 1; }
    [[ ${#code} -ge 8 ]] || { log_error "邀请码至少 8 位"; return 1; }
    local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local e_org e_app e_code e_email
    e_org=$(sql_escape_single "$SIGNUP_ORG"); e_app=$(sql_escape_single "$SIGNUP_APP")
    e_code=$(sql_escape_single "$code"); e_email=$(sql_escape_single "$email")
    # 名字固定，重跑只改额度与绑定，不清零已用次数
    run_sql "INSERT INTO invitation (owner, name, created_time, updated_time, display_name, code, is_regexp, quota, used_count, application, username, email, phone, signup_group, default_code, state)
        VALUES ('$e_org', 'bootstrap-invitation', '$now', '$now', '首个邀请码', '$e_code', false, $quota, 0, '$e_app', '', '$e_email', '', '', '$e_code', 'Active')
        ON CONFLICT (owner, name) DO UPDATE SET updated_time = EXCLUDED.updated_time, code = EXCLUDED.code, quota = EXCLUDED.quota,
          application = EXCLUDED.application, email = EXCLUDED.email, default_code = EXCLUDED.default_code, state = EXCLUDED.state;" >/dev/null \
        || { log_error "邀请码写入失败"; return 1; }
    log_ok "首个邀请码就绪（额度 $quota；码不显示）"
}

setup_signup() {
    local app=${SIGNUP_APP:-}
    if [[ -z "$app" ]]; then log_info "SIGNUP_APP 未设置，跳过自助注册"; return 0; fi
    SIGNUP_ORG=${SIGNUP_ORG:-sunmoonai}
    local captcha=${SIGNUP_CAPTCHA_RULE:-Internet-Only}
    [[ "$captcha" =~ ^(Internet-Only|Always|Dynamic|None)$ ]] || { log_error "SIGNUP_CAPTCHA_RULE 只能 Internet-Only/Always/Dynamic/None"; return 1; }
    local phone=${SIGNUP_PHONE_ENABLED:-false} sms=""
    [[ "$phone" == true || "$phone" == false ]] || { log_error "SIGNUP_PHONE_ENABLED 只能 true/false"; return 1; }
    if [[ "$phone" == true ]]; then
        sms=${SIGNUP_SMS_PROVIDER:-}
        [[ -n "$sms" ]] || { log_error "开手机号验证要 SIGNUP_SMS_PROVIDER（先在 Casdoor 建短信提供方）"; return 1; }
    fi

    local email_provider="" enable=false
    if [[ -n "${SIGNUP_SMTP_HOST:-}" ]]; then
        upsert_signup_email_provider || return 1
        email_provider=$SIGNUP_EMAIL_PROVIDER_NAME
        enable=true
    else
        log_warn "没有配置邮件服务（SIGNUP_SMTP_HOST），$app 的注册保持关闭；配好后重跑本脚本即开"
    fi

    local e_app e_items e_providers
    e_app=$(sql_escape_single "$app")
    e_items=$(sql_escape_single "$(signup_items_json "$phone")")
    e_providers=$(sql_escape_single "$(signup_providers_json "$captcha" "$email_provider" "$sms")")
    # 应用必须已由 APP_* 建好；不存在就让数据库报错（不解析 psql 的表格输出）
    run_sql "DO \$\$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM application WHERE owner = 'admin' AND name = '$e_app') THEN
          RAISE EXCEPTION 'signup app admin/% not found; create it via APP_* first', '$e_app';
        END IF; END \$\$;" >/dev/null || { log_error "找不到应用 admin/$app（先由 APP_* 建好）"; return 1; }
    run_sql "UPDATE application SET enable_sign_up = $enable, signup_items = '$e_items', providers = '$e_providers'
        WHERE owner = 'admin' AND name = '$e_app';" >/dev/null || { log_error "应用注册设置写入失败：$app"; return 1; }
    upsert_signup_invitation || return 1
    apply_signup_branding "$app" "$SIGNUP_ORG" || return 1
    if [[ "${SIGNUP_CLOSE_BUILTIN:-true}" == true ]]; then
        run_sql "UPDATE application SET enable_sign_up = false WHERE owner = 'admin' AND name = 'app-built-in';" >/dev/null \
            || { log_error "关闭 app-built-in 注册失败"; return 1; }
        log_ok "已关闭 Casdoor 自带应用 app-built-in 的注册"
    fi
    # 设计上只有 SIGNUP_APP 开注册：别的应用开着就由数据库打一条 WARNING（不替运维改，免得误伤）
    run_sql "DO \$\$ DECLARE o text; BEGIN
        SELECT string_agg(name, ',') INTO o FROM application WHERE owner = 'admin' AND enable_sign_up AND name <> '$e_app';
        IF o IS NOT NULL THEN RAISE WARNING 'signup is also enabled on: % (design: only %)', o, '$e_app'; END IF; END \$\$;" >/dev/null || true
    log_ok "自助注册：$app 注册=$enable，邀请码必填，邮箱验证码，人机校验=$captcha，手机号=$phone"
}
