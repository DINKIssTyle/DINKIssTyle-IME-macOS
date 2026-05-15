#!/bin/bash
# dictup.sh - DKST Hanja Dictionary Updater

# GitHub repository URL for the master hanja.txt
REMOTE_URL="https://raw.githubusercontent.com/DINKIssTyle/DINKIssTyle-IME-macOS/main/Resources/hanja.txt"
# Local path for the user-writable dictionary
LOCAL_PATH="$HOME/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt"
TEMP_DIR=$(mktemp -d)

echo "Checking for dictionary updates..."

# 1. Download new system dictionary
curl -s -f -o "$TEMP_DIR/new_sys.txt" "$REMOTE_URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download dictionary from GitHub."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 2. Handle local file and user data
if [ -f "$LOCAL_PATH" ]; then
    # Extract user data (everything from ###DKST to the end)
    # If ###DKST is not found, we treat the whole file as system data (to be safe)
    SEP_LINE=$(grep -n "###DKST" "$LOCAL_PATH" | head -n 1 | cut -d: -f1)
    if [ ! -z "$SEP_LINE" ]; then
        sed -n "${SEP_LINE},\$p" "$LOCAL_PATH" > "$TEMP_DIR/user_part.txt"
    else
        echo -e "\n###DKST" > "$TEMP_DIR/user_part.txt"
    fi
else
    echo -e "\n###DKST" > "$TEMP_DIR/user_part.txt"
fi

# 3. Merge: New System Data (stripping any existing ###DKST to avoid duplicates) + User Part
grep -v "###DKST" "$TEMP_DIR/new_sys.txt" > "$TEMP_DIR/merged.txt"
# Ensure there's a newline before the separator
echo "" >> "$TEMP_DIR/merged.txt"
cat "$TEMP_DIR/user_part.txt" >> "$TEMP_DIR/merged.txt"

# 4. Clean up the merged file (remove excessive blank lines)
# (Optional but nice)

# 5. Install the merged file
mkdir -p "$(dirname "$LOCAL_PATH")"
cp "$TEMP_DIR/merged.txt" "$LOCAL_PATH"

# 6. Notify the IME to reload the dictionary
# We use NSDistributedNotificationCenter via a small AppleScript or a direct tool if available.
# Since we don't have a direct CLI tool for that here, we can use osascript to tell the IME to reload if it's running.
# But the Preferences app will also trigger it if called from there.

rm -rf "$TEMP_DIR"
echo "Dictionary update successful!"
