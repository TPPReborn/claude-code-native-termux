# Patch Notes: Claude Code Native on Termux Android ARM64

## Tested environment

- OS/kernel: Android Termux on `aarch64` / `arm64-v8a`
- Node.js: `v24.14.0`
- npm: `11.12.1`
- Claude Code: `2.1.138`
- Native package: `@anthropic-ai/claude-code-linux-arm64@2.1.138`

## Timeline of fixes

### 1. Native package install

Problem:

```text
Unsupported platform: android arm64
```

Fix:

```sh
npm install -g @anthropic-ai/claude-code@2.1.138
npm install -g @anthropic-ai/claude-code-linux-arm64@2.1.138 --force
```

### 2. First wrapper attempt with glibc-runner

Initial wrapper used `glibc-runner`, and `claude --version` worked. But Claude Bash tool inherited a PATH with:

```text
/data/data/com.termux/files/usr/glibc/bin
```

at the front. This caused commands like `ls` to resolve to glibc coreutils and fail in Android shell contexts.

### 3. Bash tool PATH fix

Wrapper was changed to restore Termux PATH. This fixed `pwd && ls -la` in Claude Bash tool.

### 4. Direct glibc bash failure

Direct execution failed:

```text
/data/data/com.termux/files/usr/glibc/bin/bash: error while loading shared libraries: /data/data/com.termux/files/usr/glibc/lib/libc.so: invalid ELF header
```

Root cause: Termux session had:

```text
LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec-ld-preload.so
```

Fix: save real ELF as `bash.glibc-real` and replace `glibc/bin/bash` with wrapper that unsets `LD_PRELOAD`.

### 5. Final Claude wrapper

Final wrapper does not call `glibc-runner --shell`, does not call `glibc/bin/bash`, and does not export `LD_LIBRARY_PATH`.

It uses:

```sh
unset LD_PRELOAD
exec "$GLIBC_LDSO" --library-path "$GLIBC_PREFIX/lib" "$CLAUDE_NATIVE" "$@"
```

This keeps glibc library lookup local to the Claude process while preserving clean child process environment for hooks and Bash tools.

## Final verification commands

```sh
claude --version
bash -lc 'claude --version'
zsh -lc 'claude --version'
/data/data/com.termux/files/usr/glibc/bin/bash --version
/bin/sh -c 'echo sh_ok'
claude -p 'Reply exactly: CLAUDE_OK' --permission-mode dontAsk
claude -p "Use Bash to run exactly: pwd && command -v ls && ls -la | head -5. Then answer TEST_OK." --allowedTools Bash --permission-mode dontAsk
```
