#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DKST_RELEASE_CHANNEL="beta"

exec "${SCRIPT_DIR}/install.sh"
