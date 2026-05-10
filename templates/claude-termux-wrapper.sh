#!/data/data/com.termux/files/usr/bin/bash
# Termux Android compatibility wrapper for Anthropic Claude Code native Linux ARM64 binary.
# Official npm platform detection rejects android-arm64. This wrapper starts the
# Linux ARM64 native binary with Termux glibc loader directly.
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

# Termux sessions commonly export LD_PRELOAD=.../libtermux-exec-ld-preload.so.
# That Android/Bionic preload breaks glibc programs with:
#   glibc/lib/libc.so: invalid ELF header
# Use loader-local --library-path; do not export LD_LIBRARY_PATH to hooks/tools.
unset LD_PRELOAD
exec "$GLIBC_LDSO" --library-path "$GLIBC_PREFIX/lib" "$CLAUDE_NATIVE" "$@"
