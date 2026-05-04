#!/bin/bash
set -euo pipefail

INSTALL_SH_URL="https://raw.githubusercontent.com/DINKIssTyle/DINKIssTyle-IME-macOS/main/install.sh"
export DKST_RELEASE_CHANNEL="beta"

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${SCRIPT_DIR}/install.sh" ]; then
        exec "${SCRIPT_DIR}/install.sh"
    fi
fi

exec /bin/bash -c "$(curl -fsSL "$INSTALL_SH_URL")"
