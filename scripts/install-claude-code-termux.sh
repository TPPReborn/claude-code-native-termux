#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

CLAUDE_VERSION="${CLAUDE_VERSION:-2.1.138}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
NPM_BIN="${NPM_BIN:-npm}"
CLAUDE_PKG_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"
CLAUDE_LINUX_ARM64_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code-linux-arm64"
CLAUDE_WRAPPER="$CLAUDE_PKG_DIR/bin/claude.exe"
GLIBC_PREFIX="$PREFIX/glibc"
GLIBC_BASH="$GLIBC_PREFIX/bin/bash"
GLIBC_BASH_REAL="$GLIBC_PREFIX/bin/bash.glibc-real"
GLIBC_LDSO="$GLIBC_PREFIX/bin/ld.so"
SETTINGS_FILE="$HOME/.claude/settings.json"

log() { printf '[install] %s\n' "$*"; }
fail() { printf '[install:error] %s\n' "$*" >&2; exit 1; }

command -v "$NPM_BIN" >/dev/null 2>&1 || fail "npm not found"
[ -x "$GLIBC_LDSO" ] || fail "glibc loader missing: $GLIBC_LDSO"

log "Installing Claude Code wrapper package @anthropic-ai/claude-code@$CLAUDE_VERSION"
"$NPM_BIN" install -g "@anthropic-ai/claude-code@$CLAUDE_VERSION"

log "Installing native Linux ARM64 binary package @anthropic-ai/claude-code-linux-arm64@$CLAUDE_VERSION"
"$NPM_BIN" install -g "@anthropic-ai/claude-code-linux-arm64@$CLAUDE_VERSION" --force

[ -x "$CLAUDE_LINUX_ARM64_DIR/claude" ] || fail "native binary not found: $CLAUDE_LINUX_ARM64_DIR/claude"
[ -d "$CLAUDE_PKG_DIR/bin" ] || fail "Claude package bin dir missing: $CLAUDE_PKG_DIR/bin"

if [ -e "$CLAUDE_WRAPPER" ]; then
  backup="$CLAUDE_WRAPPER.before-termux-patch.$(date +%Y%m%d%H%M%S)"
  cp -p "$CLAUDE_WRAPPER" "$backup"
  log "Backed up existing Claude wrapper to $backup"
fi

log "Patching Claude wrapper: $CLAUDE_WRAPPER"
cat > "$CLAUDE_WRAPPER" <<'WRAPPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export DISABLE_AUTOUPDATER="${DISABLE_AUTOUPDATER:-1}"
CLAUDE_NATIVE="/data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code-linux-arm64/claude"
GLIBC_PREFIX="/data/data/com.termux/files/usr/glibc"
GLIBC_LDSO="$GLIBC_PREFIX/bin/ld.so"
if [ ! -x "$CLAUDE_NATIVE" ]; then
  echo "Error: Claude Code Linux ARM64 native binary not found at $CLAUDE_NATIVE" >&2
  echo "Try: npm install -g @anthropic-ai/claude-code-linux-arm64 --force" >&2
  exit 127
fi
if [ ! -x "$GLIBC_LDSO" ]; then
  echo "Error: Termux glibc loader missing: $GLIBC_LDSO" >&2
  exit 127
fi
unset LD_PRELOAD
exec "$GLIBC_LDSO" --library-path "$GLIBC_PREFIX/lib" "$CLAUDE_NATIVE" "$@"
WRAPPER
chmod 755 "$CLAUDE_WRAPPER"

log "Disabling Claude auto-updater in $SETTINGS_FILE"
mkdir -p "$(dirname "$SETTINGS_FILE")"
if command -v python3 >/dev/null 2>&1; then
  SETTINGS_FILE="$SETTINGS_FILE" python3 - <<'PYJSON'
import json, os
path = os.environ['SETTINGS_FILE']
data = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError:
        backup = path + '.invalid-json.bak'
        os.replace(path, backup)
        data = {}
data.setdefault('env', {})['DISABLE_AUTOUPDATER'] = '1'
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYJSON
else
  cat > "$SETTINGS_FILE" <<'JSON'
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  }
}
JSON
fi

if [ -x "$GLIBC_BASH" ] && file "$GLIBC_BASH" 2>/dev/null | grep -q 'ELF'; then
  log "Patching glibc bash wrapper to protect against LD_PRELOAD"
  if [ ! -e "$GLIBC_BASH_REAL" ]; then
    cp -p "$GLIBC_BASH" "$GLIBC_BASH_REAL"
  fi
  cat > "$GLIBC_BASH" <<'BASHWRAP'
#!/data/data/com.termux/files/usr/bin/bash
REAL="/data/data/com.termux/files/usr/glibc/bin/bash.glibc-real"
if [ ! -x "$REAL" ]; then
  echo "glibc bash real binary missing: $REAL" >&2
  exit 127
fi
unset LD_PRELOAD
argv0="${0##*/}"
exec -a "$argv0" "$REAL" "$@"
BASHWRAP
  chmod 755 "$GLIBC_BASH"
else
  log "glibc bash already appears patched or missing; skipping bash wrapper patch"
fi

log "Done. Run: hash -r 2>/dev/null || true; rehash 2>/dev/null || true"
log "Claude version: $(claude --version 2>&1 || true)"
