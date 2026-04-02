#!/bin/bash
set -euo pipefail

case "${1:-}" in
  auto)
    echo "level auto" > /proc/acpi/ibm/fan
    systemctl start thinkfan 2>/dev/null || true
    ;;
  [0-7])
    systemctl stop thinkfan 2>/dev/null || true
    echo "level $1" > /proc/acpi/ibm/fan
    ;;
  full)
    systemctl stop thinkfan 2>/dev/null || true
    echo "level full-speed" > /proc/acpi/ibm/fan
    ;;
  *)
    echo "Usage: fan-set {auto|0-7|full}" >&2
    exit 1
    ;;
esac
