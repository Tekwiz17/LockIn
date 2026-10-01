#!/usr/bin/env python3
"""Deterministic, dependency-free Xcode project generator (output is committed)."""
from pathlib import Path
import hashlib,json,plistlib
root=Path(__file__).resolve().parents[1]
objects={}
def uid(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def obj(key,isa,**fields):
 i=uid(key); objects[i]={'isa':isa,**fields}; return i
def ref(path,kind):return obj('file:'+path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='<group>')
def build(key,file,**extra):return obj('build:'+key,'PBXBuildFile',fileRef=file,**extra)
def phase(key,isa,files,**fields):return obj(key,isa,buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0,**fields)
appSwift=sorted(str(p.relative_to(root)) for folder in ['Core','MacApp'] for p in (root/folder).glob('*.swift'))
sharedDock='DockSupport/DockStore.swift'
appSwift.append(sharedDock)
refs={p:ref(p,'sourcecode.swift') for p in appSwift}
helperMain='DockRecovery/main.swift'; refs[helperMain]=ref(helperMain,'sourcecode.swift')
handler='SafariExtension/SafariWebExtensionHandler.swift'; refs[handler]=ref(handler,'sourcecode.swift')
assets=ref('Assets.xcassets','folder.assetcatalog')
# Resource children at bundle root are essential: Safari looks for manifest.json here.
web=[]
for p in sorted((root/'BrowserExtensions/Safari').iterdir()):
 rel=str(p.relative_to(root)); kind='folder' if p.is_dir() else {'.js':'sourcecode.javascript','.json':'text.json','.html':'text.html','.css':'text.css'}[p.suffix]
 web.append(ref(rel,kind))
appProduct=obj('appProduct','PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='LockIn.app',sourceTree='BUILT_PRODUCTS_DIR')
extProduct=obj('extProduct','PBXFileReference',explicitFileType='wrapper.app-extension',includeInIndex=0,path='LockInSafari.appex',sourceTree='BUILT_PRODUCTS_DIR')
helperProduct=obj('helperProduct','PBXFileReference',explicitFileType='compiled.mach-o.executable',includeInIndex=0,path='LockInDockRecovery',sourceTree='BUILT_PRODUCTS_DIR')
products=obj('products','PBXGroup',children=[appProduct,extProduct,helperProduct],name='Products',sourceTree='<group>')
appSources=phase('appSources','PBXSourcesBuildPhase',[build(p,refs[p]) for p in appSwift])
extSources=phase('extSources','PBXSourcesBuildPhase',[build(handler,refs[handler])])
helperSources=phase('helperSources','PBXSourcesBuildPhase',[build('helper:'+p,refs[p]) for p in ['Core/DockLayout.swift',sharedDock,helperMain]])
helperFramework=phase('helperFrameworks','PBXFrameworksBuildPhase',[])
copyHelper=phase('copyHelper','PBXCopyFilesBuildPhase',[build('copyHelper',helperProduct,settings={'ATTRIBUTES':['CodeSignOnCopy']})],dstPath='',dstSubfolderSpec=7,name='Embed Dock Recovery Helper')
appResources=phase('appResources','PBXResourcesBuildPhase',[build('assets',assets)])
extResources=phase('extResources','PBXResourcesBuildPhase',[build('web:'+f,f) for f in web])
appFramework=phase('appFrameworks','PBXFrameworksBuildPhase',[])
extFramework=phase('extFrameworks','PBXFrameworksBuildPhase',[])
embed=phase('embed','PBXCopyFilesBuildPhase',[build('embed',extProduct,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})],dstPath='',dstSubfolderSpec=13,name='Embed App Extensions')
base={'MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','CODE_SIGN_IDENTITY':'-','CODE_SIGN_STYLE':'Manual','DEVELOPMENT_TEAM':'','ENABLE_HARDENED_RUNTIME':'NO','SWIFT_STRICT_CONCURRENCY':'minimal','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
def configs(key,settings):
 ids=[]
 for name in ['Debug','Release']:
  s={**settings,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'}
  if name=='Debug':s['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
  ids.append(obj(key+name,'XCBuildConfiguration',buildSettings=s,name=name))
 return obj(key+'List','XCConfigurationList',buildConfigurations=ids,defaultConfigurationIsVisible=0,defaultConfigurationName='Debug')
projectConfig=configs('projectConfig',base)
appConfig=configs('appConfig',{'PRODUCT_BUNDLE_IDENTIFIER':'com.lockin.mac','PRODUCT_NAME':'LockIn','INFOPLIST_FILE':'MacApp/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ENABLE_APP_SANDBOX':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks'],'COMBINE_HIDPI_IMAGES':'YES','COPY_PHASE_STRIP':'NO','STRIP_INSTALLED_PRODUCT':'NO','ENABLE_DEBUG_DYLIB':'NO'})
extConfig=configs('extConfig',{'PRODUCT_BUNDLE_IDENTIFIER':'com.lockin.mac.SafariExtension','PRODUCT_NAME':'LockInSafari','INFOPLIST_FILE':'SafariExtension/Info.plist','CODE_SIGN_ENTITLEMENTS':'SafariExtension/LockInSafari.entitlements','ENABLE_APP_SANDBOX':'YES','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','COPY_PHASE_STRIP':'NO','STRIP_INSTALLED_PRODUCT':'NO','ENABLE_DEBUG_DYLIB':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks','@executable_path/../../../../Frameworks']})
helperConfig=configs('helperConfig',{'PRODUCT_NAME':'LockInDockRecovery','SKIP_INSTALL':'YES','COPY_PHASE_STRIP':'NO','STRIP_INSTALLED_PRODUCT':'NO','ENABLE_APP_SANDBOX':'NO'})
projectID=uid('project');appID=uid('app');extID=uid('ext');helperID=uid('helper')
proxy=obj('proxy','PBXContainerItemProxy',containerPortal=projectID,proxyType=1,remoteGlobalIDString=extID,remoteInfo='LockInSafari')
dep=obj('dependency','PBXTargetDependency',target=extID,targetProxy=proxy)
helperProxy=obj('helperProxy','PBXContainerItemProxy',containerPortal=projectID,proxyType=1,remoteGlobalIDString=helperID,remoteInfo='LockInDockRecovery')
helperDep=obj('helperDependency','PBXTargetDependency',target=helperID,targetProxy=helperProxy)
obj('helper','PBXNativeTarget',buildConfigurationList=helperConfig,buildPhases=[helperSources,helperFramework],buildRules=[],dependencies=[],name='LockInDockRecovery',productName='LockInDockRecovery',productReference=helperProduct,productType='com.apple.product-type.tool')
obj('app','PBXNativeTarget',buildConfigurationList=appConfig,buildPhases=[appSources,appFramework,appResources,embed,copyHelper],buildRules=[],dependencies=[dep,helperDep],name='LockIn',productName='LockIn',productReference=appProduct,productType='com.apple.product-type.application')
obj('ext','PBXNativeTarget',buildConfigurationList=extConfig,buildPhases=[extSources,extFramework,extResources],buildRules=[],dependencies=[],name='LockInSafari',productName='LockInSafari',productReference=extProduct,productType='com.apple.product-type.app-extension')
extra=[ref('MacApp/Info.plist','text.plist.xml'),ref('SafariExtension/Info.plist','text.plist.xml'),ref('SafariExtension/LockInSafari.entitlements','text.plist.entitlements'),ref('README.md','net.daringfireball.markdown')]
group=obj('main','PBXGroup',children=list(refs.values())+[assets]+web+extra+[products],sourceTree='<group>')
obj('project','PBXProject',attributes={'LastUpgradeCheck':'1600','BuildIndependentTargetsInParallel':'YES','TargetAttributes':{appID:{'CreatedOnToolsVersion':'16.0'},extID:{'CreatedOnToolsVersion':'16.0'}}},buildConfigurationList=projectConfig,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[appID,extID,helperID])
def fmt(v,level=0):
 if isinstance(v,dict):return '{\n'+''.join('\t'*(level+1)+json.dumps(str(k))+' = '+fmt(x,level+1)+';\n' for k,x in v.items())+'\t'*level+'}'
 if isinstance(v,list):return '( '+', '.join(fmt(x,level) for x in v)+(' ,' if v else '')+' )'
 if isinstance(v,int):return str(v)
 return json.dumps(v)
(root/'LockIn.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n'+fmt({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':projectID})+'\n')
baseInfo={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'1.6.3','CFBundleVersion':'10','LSMinimumSystemVersion':'$(MACOSX_DEPLOYMENT_TARGET)'}
appInfo={**baseInfo,'CFBundlePackageType':'APPL','NSPrincipalClass':'NSApplication','NSHighResolutionCapable':True,'LSApplicationCategoryType':'public.app-category.productivity','CFBundleURLTypes':[{'CFBundleURLName':'com.lockin.open','CFBundleURLSchemes':['lockin']}], 'NSAppTransportSecurity':{'NSAllowsLocalNetworking':True}}
extInfo={**baseInfo,'CFBundlePackageType':'XPC!','CFBundleDisplayName':'LockIn','NSExtension':{'NSExtensionPointIdentifier':'com.apple.Safari.web-extension','NSExtensionPrincipalClass':'$(PRODUCT_MODULE_NAME).SafariWebExtensionHandler'},'NSAppTransportSecurity':{'NSAllowsLocalNetworking':True}}
for path,data in [('MacApp/Info.plist',appInfo),('SafariExtension/Info.plist',extInfo),('SafariExtension/LockInSafari.entitlements',{'com.apple.security.app-sandbox':True,'com.apple.security.network.client':True})]:
 (root/path).write_bytes(plistlib.dumps(data))
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appID}" BuildableName="LockIn.app" BlueprintName="LockIn" ReferencedContainer="container:LockIn.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appID}" BuildableName="LockIn.app" BlueprintName="LockIn" ReferencedContainer="container:LockIn.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{appID}" BuildableName="LockIn.app" BlueprintName="LockIn" ReferencedContainer="container:LockIn.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'LockIn.xcodeproj/xcshareddata/xcschemes/LockIn.xcscheme').write_text(scheme)
print(f'Generated Xcode project: {len(appSwift)} app Swift files, embedded Safari extension.')
