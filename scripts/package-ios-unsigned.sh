#!/usr/bin/env bash
set -euo pipefail
app="build/ios/iphoneos/Runner.app"
destination="build/ios/unsigned"
test -d "$app" || { echo 'Runner.app was not generated'; exit 1; }
mkdir -p "$destination/Payload"
ditto "$app" "$destination/Payload/Runner.app"
(cd "$destination" && ditto -c -k --keepParent Payload ZOVV-unsigned.ipa)
unzip -t "$destination/ZOVV-unsigned.ipa"
