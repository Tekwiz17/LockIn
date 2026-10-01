#!/usr/bin/env python3
"""Materialize the two targets from one browser source tree. No dependencies."""
import json, shutil
from pathlib import Path
root = Path(__file__).resolve().parents[1]
for name in ('Chrome', 'Safari'):
    dest = root / 'BrowserExtensions' / name
    if dest.exists(): shutil.rmtree(dest)
    shutil.copytree(root / 'BrowserExtensions/Shared', dest)
    manifest = {
        'manifest_version': 3, 'name': 'LockIn', 'version': '1.6.2',
        'description': 'Your Mac focus sessions, in your browser. Local sync only.',
        'permissions': ['storage', 'alarms', 'tabs', 'declarativeNetRequest'],
        'host_permissions': ['http://*/*', 'https://*/*'],
        'action': {'default_title': 'LockIn', 'default_popup': 'popup.html', 'default_icon': {'16':'icons/16.png','32':'icons/32.png'}},
        'icons': {'16':'icons/16.png','32':'icons/32.png','48':'icons/48.png','128':'icons/128.png'},
        'background': {'service_worker': 'background.js'} if name == 'Chrome' else {'scripts':['ai-policy.js','rules.js','background.js'], 'persistent':False},
        'content_scripts': [{'matches':['http://*/*','https://*/*'],'js':['ai-policy.js','ai-hide.js','guard.js'],'run_at':'document_start'}],
        'web_accessible_resources': [{'resources':['blocked.html','blocked.js','ai-policy.js','rules.js','style.css','icons/*'],'matches':['http://*/*','https://*/*']}],
        'content_security_policy': {'extension_pages': "script-src 'self'; object-src 'none'; connect-src http://127.0.0.1:19287;"}
    }
    if name == 'Chrome': manifest['minimum_chrome_version'] = '120'
    (dest/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('Built Chrome and Safari from shared sources.')
