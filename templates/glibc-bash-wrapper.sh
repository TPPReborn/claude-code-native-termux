#!/data/data/com.termux/files/usr/bin/bash
# Compatibility wrapper: run glibc bash from a Termux session that has
# Termux libtermux-exec in LD_PRELOAD. That preload is built for Android/Bionic
# and breaks glibc programs with: glibc/lib/libc.so: invalid ELF header.
REAL="/data/data/com.termux/files/usr/glibc/bin/bash.glibc-real"
if [ ! -x "$REAL" ]; then
  echo "glibc bash real binary missing: $REAL" >&2
  exit 127
fi
unset LD_PRELOAD
# Preserve sh-vs-bash behavior when invoked via glibc/bin/sh -> bash symlink.
argv0="${0##*/}"
exec -a "$argv0" "$REAL" "$@"
