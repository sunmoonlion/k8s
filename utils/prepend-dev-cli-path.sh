#!/usr/bin/env bash
# 将常见 CLI 安装目录 prepend 到 PATH（conda / 窄 PATH 子进程友好；与 kind-infrastructure/kind-cli 行为一致）
# 用法：source 本文件后执行 prepend_dev_cli_to_path

prepend_dev_cli_to_path() {
    local d
    for d in "${HOME}/.local/bin" /usr/local/bin; do
        [[ -d "$d" ]] || continue
        case ":${PATH}:" in *":${d}:"*) ;; *) export PATH="${d}:${PATH}" ;; esac
    done
}
