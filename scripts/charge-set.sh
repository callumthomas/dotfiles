#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  full)   exec /usr/sbin/tlp setcharge 95 100 BAT0 ;;
  normal) exec /usr/sbin/tlp setcharge 75 80 BAT0 ;;
  *)      echo "usage: charge-set full|normal" >&2; exit 2 ;;
esac
