#!/bin/bash
# dictup.sh - DKST Hanja Dictionary Updater (Improved)
set -euo pipefail

REMOTE_URL="https://raw.githubusercontent.com/DINKIssTyle/DINKIssTyle-IME-macOS/main/Resources/hanja.txt"
LOCAL_PATH="${DKST_DICTIONARY_PATH:-${HOME}/Library/Application Support/DKST Korean IME/hanja.txt}"

TEMP_DIR=$(mktemp -d)
STAGED=""
cleanup() {
    rm -rf "$TEMP_DIR"
    if [ -n "$STAGED" ]; then
        rm -f "$STAGED"
    fi
}
trap cleanup EXIT
NEW_SYS="$TEMP_DIR/new_sys.txt"
USER_PART="$TEMP_DIR/user_part.txt"
MERGED="$TEMP_DIR/merged.txt"

echo "Checking for dictionary updates..."

# 1. Download new system dictionary
# Use -L for redirects and -f to fail on 404
if ! curl -L -s -f -o "$NEW_SYS" "$REMOTE_URL" || [ ! -s "$NEW_SYS" ]; then
    echo "Error: Failed to download dictionary from GitHub or file is empty."
    exit 1
fi

# 2. Extract System Part from Remote (everything before ###DKST)
REMOTE_SEP=$(awk '/^###DKST\r?$/ { print NR; exit }' "$NEW_SYS")
if [ ! -z "$REMOTE_SEP" ]; then
    # Keep only the part before the separator from remote
    head -n $((REMOTE_SEP - 1)) "$NEW_SYS" > "$NEW_SYS.tmp"
    mv "$NEW_SYS.tmp" "$NEW_SYS"
fi

# 3. Handle local file and user data
if [ -f "$LOCAL_PATH" ]; then
    # Extract user data (everything from ###DKST to the end)
    LOCAL_SEP=$(awk '/^###DKST\r?$/ { print NR; exit }' "$LOCAL_PATH")
    if [ ! -z "$LOCAL_SEP" ]; then
        sed -n "${LOCAL_SEP},\$p" "$LOCAL_PATH" > "$USER_PART"
    else
        echo -e "\n###DKST" > "$USER_PART"
    fi
else
    echo -e "\n###DKST" > "$USER_PART"
fi

# 4. Merge: New System Data + User Part
cat "$NEW_SYS" > "$MERGED"
# Ensure there is exactly one newline before the separator
echo "" >> "$MERGED"
cat "$USER_PART" >> "$MERGED"

# 5. Install the merged file
mkdir -p "$(dirname "$LOCAL_PATH")"
if [ -d "$LOCAL_PATH" ]; then
    echo "Error: Dictionary path is a directory." >&2
    exit 1
fi
# Stage on the destination filesystem so rename replaces the file atomically.
STAGED=$(mktemp "$(dirname "$LOCAL_PATH")/.hanja.XXXXXX")
cp "$MERGED" "$STAGED"
mv -f "$STAGED" "$LOCAL_PATH"
STAGED=""

echo "Dictionary update successful!"
