#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-$PWD/Build/Build/Products/Debug/LockIn.app}"
if [[ ! -d "$app/Contents/PlugIns/LockInSafari.appex" ]]; then
  echo 'Build with Scripts/verify-mac.sh first, or pass the full path to your built LockIn.app.'
  exit 1
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
pluginkit -a "$app/Contents/PlugIns/LockInSafari.appex"
open "$app"
echo 'In Safari: Develop → Allow Unsigned Extensions, then Settings → Extensions → LockIn.'
