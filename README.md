# Claude Code Native on Termux Android ARM64

Patch kit untuk menjalankan **Claude Code native** di **Termux Android arm64** menggunakan binary resmi `linux-arm64` dari paket npm Anthropic.

> Status hasil patch lokal: terverifikasi pada Termux Android `aarch64`, Node.js `v24.14.0`, npm `11.12.1`, Claude Code `2.1.138`.

## Masalah yang diperbaiki

Install resmi:

```sh
npm install -g @anthropic-ai/claude-code
```

pada Termux Android menghasilkan warning/error postinstall:

```text
[@anthropic-ai/claude-code postinstall] Unsupported platform: android arm64
Supported: darwin-arm64, darwin-x64, linux-x64, linux-arm64, ...
```

Selain itu, menjalankan binary glibc langsung di sesi Termux dapat memicu:

```text
bash: error while loading shared libraries: /data/data/com.termux/files/usr/glibc/lib/libc.so: invalid ELF header
/data/data/com.termux/files/usr/glibc/bin/ls: error while loading shared libraries: ... invalid ELF header
```

Root cause utama:

1. Node/npm di Termux melaporkan platform sebagai `android arm64`, sementara Claude Code menyediakan binary native sebagai `linux-arm64`.
2. Termux sering memakai `LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec-ld-preload.so`; preload Android/Bionic ini merusak proses glibc.
3. `glibc-runner` menambahkan `/data/data/com.termux/files/usr/glibc/bin` ke awal `PATH`, sehingga tool Bash Claude bisa menjalankan glibc coreutils langsung (`glibc/bin/ls`) dan gagal.
4. Mengekspor `LD_LIBRARY_PATH` glibc ke child process membuat hook/tool Android/Bionic seperti `/bin/sh` ikut gagal link.

Patch ini menghindari semua itu dengan:

- memasang paket resmi wrapper Claude Code;
- memaksa pemasangan paket binary resmi `@anthropic-ai/claude-code-linux-arm64`;
- mengganti wrapper `claude` agar memakai loader glibc langsung dengan `--library-path`, tanpa mengekspor `LD_LIBRARY_PATH`;
- menonaktifkan `LD_PRELOAD` hanya untuk proses Claude native;
- menjaga `PATH` tetap mengarah ke binary Termux normal;
- opsional: memberi wrapper aman untuk `/data/data/com.termux/files/usr/glibc/bin/bash`.

## Quick start

### Install langsung dari repo GitHub

Jalankan di Termux:

```sh
pkg update
pkg install -y git nodejs-lts glibc glibc-runner patchelf
git clone https://github.com/dbgid/claude-code-native-termux.git
cd claude-code-native-termux
chmod +x scripts/*.sh
./scripts/install-claude-code-termux.sh
./scripts/verify-claude-code-termux.sh
```

### One-liner install

Jika dependency dasar sudah tersedia:

```sh
git clone https://github.com/dbgid/claude-code-native-termux.git && \
cd claude-code-native-termux && \
chmod +x scripts/*.sh && \
./scripts/install-claude-code-termux.sh && \
./scripts/verify-claude-code-termux.sh
```

### Install versi Claude tertentu

```sh
CLAUDE_VERSION=2.1.138 ./scripts/install-claude-code-termux.sh
```

Jika shell Anda masih cache command lama:

```sh
hash -r 2>/dev/null || true
rehash 2>/dev/null || true
```

atau tutup dan buka ulang Termux.

## Requirement

- Termux di Android arm64/aarch64.
- Node.js 18+ dan npm.
- Paket glibc Termux tersedia, terutama loader:
  - `/data/data/com.termux/files/usr/glibc/bin/ld.so`
  - `/data/data/com.termux/files/usr/glibc/lib`
- `bash`, `npm`, `sed`, `cp`, `chmod`.

Contoh dependency Termux yang biasanya diperlukan:

```sh
pkg install nodejs-lts glibc glibc-runner patchelf ripgrep
```

> Nama paket glibc dapat berbeda tergantung repo Termux yang Anda pakai.

## Instalasi manual

```sh
npm install -g @anthropic-ai/claude-code@2.1.138
npm install -g @anthropic-ai/claude-code-linux-arm64@2.1.138 --force
```

Lalu patch file:

```text
/data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
```

isi finalnya tersedia di:

```text
templates/claude-termux-wrapper.sh
```

## Wrapper final Claude

Inti wrapper:

```sh
unset LD_PRELOAD
exec /data/data/com.termux/files/usr/glibc/bin/ld.so \
  --library-path /data/data/com.termux/files/usr/glibc/lib \
  /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code-linux-arm64/claude "$@"
```

Catatan penting:

- **Jangan** export `LD_LIBRARY_PATH` glibc secara global.
- **Jangan** menjalankan Claude lewat `glibc-runner --shell` untuk use-case ini.
- **Jangan** taruh `/data/data/com.termux/files/usr/glibc/bin` di awal `PATH` untuk sesi Claude Bash tool.

## Disable auto-update Claude Code

Patch ini menonaktifkan auto-updater agar wrapper Termux tidak tertimpa otomatis.

Global Claude settings yang direkomendasikan:

```json
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  }
}
```

Installer juga menambahkan env ini tanpa menghapus setting lain.

## Patch glibc bash opsional

Jika direct call berikut gagal:

```sh
/data/data/com.termux/files/usr/glibc/bin/bash --version
```

dengan error `invalid ELF header`, jalankan installer. Binary asli akan disimpan sebagai:

```text
/data/data/com.termux/files/usr/glibc/bin/bash.glibc-real
```

Lalu `/data/data/com.termux/files/usr/glibc/bin/bash` menjadi wrapper kecil yang melakukan:

```sh
unset LD_PRELOAD
exec -a "$argv0" "$REAL" "$@"
```

Template tersedia di:

```text
templates/glibc-bash-wrapper.sh
```

## Verifikasi

Jalankan:

```sh
./scripts/verify-claude-code-termux.sh
```

Expected result minimal:

```text
2.1.138 (Claude Code)
loggedIn: true     # jika sudah login
Bash tool smoke: TEST_OK
```

Manual smoke test:

```sh
claude --version
claude auth status
claude -p "Reply exactly: CLAUDE_OK" --permission-mode dontAsk
claude -p "Use Bash to run exactly: pwd && command -v ls && ls -la | head -5. Then answer TEST_OK." --allowedTools Bash --permission-mode dontAsk
```

## File dalam repo

```text
README.md
scripts/install-claude-code-termux.sh
scripts/verify-claude-code-termux.sh
templates/claude-termux-wrapper.sh
templates/glibc-bash-wrapper.sh
docs/PATCH_NOTES.md
.github/workflows/shellcheck.yml
```

## Troubleshooting

### `claude --version` masih error `invalid ELF header`

Coba reset hash shell:

```sh
hash -r 2>/dev/null || true
rehash 2>/dev/null || true
```

Lalu cek wrapper:

```sh
sed -n '1,120p' /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
```

Pastikan ada:

```sh
unset LD_PRELOAD
exec "$GLIBC_LDSO" --library-path "$GLIBC_PREFIX/lib" "$CLAUDE_NATIVE" "$@"
```

### Bash tool Claude menjalankan `glibc/bin/ls`

Cek PATH dalam sesi Claude Bash tool:

```sh
claude -p "Use Bash to run: command -v ls && echo \$PATH" --allowedTools Bash --permission-mode dontAsk
```

`ls` seharusnya resolve ke:

```text
/data/data/com.termux/files/usr/bin/ls
```

bukan:

```text
/data/data/com.termux/files/usr/glibc/bin/ls
```

### Hook Claude gagal dengan `/bin/sh` bad ELF magic

Itu biasanya karena `LD_LIBRARY_PATH` glibc diwariskan. Wrapper final di repo ini tidak mengekspor `LD_LIBRARY_PATH`, hanya memakai loader-local `--library-path`.

## Catatan keamanan

- Repo ini tidak menyertakan binary Claude Code.
- Binary tetap diambil dari package npm resmi Anthropic.
- Patch hanya mengganti wrapper lokal agar compatible dengan Termux Android.
- Jangan commit token, `~/.claude`, atau file auth.

## Lisensi

Patch script dan dokumentasi di repo ini dapat dirilis sebagai MIT. Claude Code tetap mengikuti lisensi dan ketentuan Anthropic.
