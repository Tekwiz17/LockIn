#!/usr/bin/env python3
"""Portable structural validation; does not substitute for Xcode compilation."""
from pathlib import Path
import json, plistlib, re, subprocess, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
pbx=(root/'LockIn.xcodeproj/project.pbxproj').read_text()
for p in [*root.glob('Core/*.swift'),*root.glob('MacApp/*.swift'),*root.glob('SafariExtension/*.swift'),*root.glob('DockSupport/*.swift'),*root.glob('DockRecovery/*.swift')]:
 assert str(p.relative_to(root)) in pbx, f'Missing Xcode source membership: {p}'
assert 'com.apple.product-type.tool' in pbx and 'Embed Dock Recovery Helper' in pbx
assert 'com.apple.product-type.app-extension' in pbx and 'Embed App Extensions' in pbx
for path in re.findall(r'"path" = "([^"]+)"',pbx):
 if path.endswith(('.app','.appex')) or path == 'LockInDockRecovery': continue
 assert (root/path).exists(),f'Missing project file: {path}'
for p in root.rglob('*.plist'): plistlib.loads(p.read_bytes())
for p in root.rglob('*.entitlements'): plistlib.loads(p.read_bytes())
for p in root.rglob('*.xcscheme'): ET.parse(p)
for p in root.rglob('*.json'): json.loads(p.read_text())
for name in ['Chrome','Safari']:
 folder=root/'BrowserExtensions'/name; m=json.loads((folder/'manifest.json').read_text())
 assert m['manifest_version']==3
 files=[m['action']['default_popup'], *m['icons'].values(), *m['action']['default_icon'].values()]
 files+=([m['background']['service_worker']] if name=='Chrome' else m['background']['scripts'])
 for script in m['content_scripts']: files+=script['js']
 for file in files: assert (folder/file).is_file(),f'Missing extension asset: {name}/{file}'
 for p in (root/'BrowserExtensions/Shared').rglob('*'):
  if p.is_file(): assert p.read_bytes()==(folder/p.relative_to(root/'BrowserExtensions/Shared')).read_bytes(),f'Diverged shared source: {p}'
 for p in folder.glob('*.html'):
  for asset in re.findall(r'(?:src|href)="([^"]+)"',p.read_text()):
   if '://' not in asset: assert (folder/asset).exists(),f'Missing page asset: {asset}'
for p in (root/'Assets.xcassets').rglob('Contents.json'):
 for asset in json.loads(p.read_text()).get('images',[]): assert (p.parent/asset['filename']).is_file()
for p in (root/'BrowserExtensions/Shared').glob('*.js'): subprocess.run(['node','--check',str(p)],check=True)
for p in sorted((root/'Tests').glob('*.test.js')): subprocess.run(['node',str(p)],check=True)
subprocess.run(['python3',str(root/'Tests/watchdog_test.py')],check=True)
subprocess.run(['python3',str(root/'Tests/session_recovery_test.py')],check=True)
# Optional parsers strengthen static checks when available in the development environment.
try:
 from openstep_parser import OpenStepDecoder
 parsed=OpenStepDecoder.ParseFromString(pbx)
 assert parsed['rootObject'] in parsed['objects']
 objects=parsed['objects']
 for target in parsed['objects'][parsed['rootObject']]['targets']:
  assert objects[target]['isa']=='PBXNativeTarget'
  for phase in objects[target]['buildPhases']:
   for build in objects[phase].get('files',[]): assert objects[build]['fileRef'] in objects
 helper = next(value for value in objects.values() if value.get('isa') == 'PBXNativeTarget' and value.get('name') == 'LockInDockRecovery')
 helper_sources = next(objects[phase] for phase in helper['buildPhases'] if objects[phase]['isa'] == 'PBXSourcesBuildPhase')
 helper_paths = {objects[objects[build]['fileRef']]['path'] for build in helper_sources['files']}
 assert helper_paths == {'Core/DockLayout.swift', 'DockSupport/DockStore.swift', 'DockRecovery/main.swift'}
 app = next(value for value in objects.values() if value.get('isa') == 'PBXNativeTarget' and value.get('name') == 'LockIn')
 assert any(objects[objects[d]['target']]['name'] == 'LockInDockRecovery' for d in app['dependencies'])
 assert any(objects[phase].get('name') == 'Embed Dock Recovery Helper' and int(objects[phase]['dstSubfolderSpec']) == 7 for phase in app['buildPhases'])
 print('OpenStep Xcode project parsed; helper source isolation, build dependency and Resources embedding verified.')
except ImportError: print('Optional OpenStep parser not installed; project path checks completed.')
try:
 import tree_sitter, tree_sitter_swift
 parser=tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
 for p in root.rglob('*.swift'):
  tree=parser.parse(p.read_bytes())
  assert not tree.root_node.has_error,f'Swift syntax parse failed: {p}'
 print('All Swift files passed grammar parsing (not type-checking).')
except ImportError: print('Swift syntax parser unavailable; run Scripts/verify-mac.sh for compilation.')
print('PASS: source membership, resources, manifests, assets, plist/scheme syntax, shared parity and JavaScript checks.')
