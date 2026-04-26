#!/bin/bash
set -euo pipefail

REPO="DINKIssTyle/DINKIssTyle-IME-macOS"
API_URL="https://api.github.com/repos/${REPO}/releases?per_page=1"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dkst-install.XXXXXX")"
ARCHIVE_PATH="${WORK_DIR}/source.zip"
EXTRACT_DIR="${WORK_DIR}/release"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "=========================================="
echo "      DKST 한국어 입력기 설치 준비       "
echo "=========================================="
echo "최신 릴리즈 정보를 확인 중입니다..."

RELEASE_JSON="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API_URL")"

TAG_NAME="$(printf '%s\n' "$RELEASE_JSON" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
    | head -n 1)"

SOURCE_ZIP_URL="$(printf '%s\n' "$RELEASE_JSON" \
    | sed -n 's/.*"zipball_url": *"\([^"]*\)".*/\1/p' \
    | head -n 1)"

if [ -z "$TAG_NAME" ]; then
    echo "오류: 최신 릴리즈 태그를 확인하지 못했습니다."
    exit 1
fi

if [ -z "$SOURCE_ZIP_URL" ]; then
    echo "오류: ${TAG_NAME} 릴리즈의 Source code zip 주소를 확인하지 못했습니다."
    exit 1
fi

echo "대상 릴리즈: ${TAG_NAME}"
echo "Source code zip 다운로드 중..."
curl -fL "$SOURCE_ZIP_URL" -o "$ARCHIVE_PATH"

echo "압축 해제 중..."
mkdir -p "$EXTRACT_DIR"
ditto -x -k "$ARCHIVE_PATH" "$EXTRACT_DIR"

INSTALL_COMMAND="$(find "$EXTRACT_DIR" -type f -name "install.command" -print | head -n 1)"

if [ -z "$INSTALL_COMMAND" ]; then
    echo "오류: 압축 파일 안에서 install.command를 찾지 못했습니다."
    exit 1
fi

chmod +x "$INSTALL_COMMAND"

echo ""
echo "DKST 한국어 입력기 설치 도우미를 실행합니다."
echo ""
"$INSTALL_COMMAND"
