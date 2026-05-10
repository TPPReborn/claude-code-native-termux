#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

log() { printf '[verify] %s\n' "$*"; }
run() {
  printf '\n$ %s\n' "$*"
  "$@"
}

log "Environment"
printf 'SHELL=%s\nPATH=%s\nLD_PRELOAD=%s\n' "${SHELL-}" "${PATH-}" "${LD_PRELOAD-}"

run command -v claude
run claude --version

printf '\n$ claude auth status\n'
claude auth status || true

printf '\n$ /data/data/com.termux/files/usr/glibc/bin/bash --version | head -1\n'
/data/data/com.termux/files/usr/glibc/bin/bash --version | head -1

printf '\n$ /bin/sh -c echo sh_ok\n'
/bin/sh -c 'echo sh_ok'

printf '\n$ claude -p basic smoke\n'
timeout 120s claude -p 'Reply exactly: CLAUDE_OK' --permission-mode dontAsk

printf '\n$ claude Bash tool smoke\n'
timeout 120s claude -p "Use Bash to run exactly: pwd && command -v bash && command -v ls && /bin/sh -c 'echo inner_sh_ok'. Then answer TEST_OK." --allowedTools Bash --permission-mode dontAsk

log "OK"
