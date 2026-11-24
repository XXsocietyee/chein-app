#!/usr/bin/env python3
"""Generate the app and pinned, source-only GLTFKit2 framework dependency. Does not install tools or invoke Xcode."""
import hashlib, json, os, pathlib, re, xml.etree.ElementTree as ET
ROOT = pathlib.Path(__file__).resolve().parents[1]
def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
objects = {}
def obj(object_key, **fields):
    key = ident(object_key); objects[key] = fields; return key
# Metal shaders are an opt-in build dependency: the Metal Toolchain is a separate Xcode download and may be missing on a runner.
METAL_ON = os.environ.get('CY_ENABLE_METAL') == '1'
METAL_COND = ' CY_METAL_SHADERS' if METAL_ON else ''
sources = sorted([*ROOT.glob('App/*.swift'), *ROOT.glob('App/Theme/*.swift'), *ROOT.glob('App/DesignSystem/*.swift'), *(ROOT.glob('App/DesignSystem/*.metal') if METAL_ON else []), *ROOT.glob('App/DesignFixtures/*.swift'), *ROOT.glob('App/ClubKit/*.swift'), *ROOT.glob('App/MerchantKit/*.swift'), *ROOT.glob('App/MerchantApprovals/*.swift'), *ROOT.glob('App/CityKit/*.swift'), *ROOT.glob('App/NativeGallery/*.swift'), *ROOT.glob('App/MPGap/**/*.swift'), *ROOT.glob('App/MPAssets/*.swift'), *ROOT.glob('App/*.m'), *ROOT.glob('Core/*.swift'), *ROOT.glob('Core/MPGap/**/*.swift')])
ui_source_paths = sorted(ROOT.glob('Tests/AppUITests/*.swift'))
# Compile this canonical demo source in the app only for Debug. Release AppUnit
# retains the old tests by compiling that same source in the test bundle instead.
release_test_fixture_sources = [ROOT/'App/AppStoreReviewDemoAccountAndFixtureSectionView.swift']
release_test_fixture_names = ' '.join(path.name for path in release_test_fixture_sources)
# Design fixtures and their registry stay in the Debug compile only. An empty
# directory (synthetic generator fixtures) must not change the exclusion string.
design_fixture_sources = sorted(ROOT.glob('App/DesignFixtures/*.swift'))
design_fixture_names = ' '.join(path.name for path in design_fixture_sources)
release_excluded_names = release_test_fixture_names
if design_fixture_names:
    release_excluded_names += ' '+design_fixture_names
unit_source_paths = sorted([*ROOT.glob('Tests/AppUnitTests/**/*.swift'), *release_test_fixture_sources])
# Live Activity widget extension (roam walk / play session). It compiles its own folder plus the one shared,
# Foundation/ActivityKit-only Core file that declares the ActivityAttributes; that file stays in the app too.
live_activity_shared_sources = [ROOT/'Core/QuestLiveActivityContent.swift']
live_activity_sources = sorted([*ROOT.glob('LiveActivityWidget/*.swift'), *(p for p in live_activity_shared_sources if p.is_file())])
live_activity_resources = sorted(ROOT.glob('LiveActivityWidget/*.xcstrings'))

def validate_swift_basenames(target_name, paths):
    # Swift localization extraction emits <basename>.stringsdata within each
    # target/architecture. Different directories do not make those outputs unique.
    # Reject case-only variants too, for default case-insensitive macOS volumes.
    by_stem = {}
    for path in paths:
        if path.suffix == '.swift':
            by_stem.setdefault(path.stem.casefold(), []).append(path)
    duplicates = [paths for paths in by_stem.values() if len(paths) > 1]
    if duplicates:
        details = '\n'.join('  ' + ', '.join(str(path.relative_to(ROOT)) for path in paths)
                            for paths in duplicates)
        raise SystemExit(f'Duplicate Swift basenames in target {target_name}:\n{details}\n'
                         'Rename a source file; keep Swift localization extraction enabled.')

# Check every target before writing any generated project or scheme. Identical
# basenames in separate targets (for example Core and AppUnit tests) are valid.
for target_name, paths in [('Questify', sources), ('QuestifyUITests', ui_source_paths),
                           ('QuestifyAppUnitTests', unit_source_paths), ('QuestifyLiveActivity', live_activity_sources)]:
    validate_swift_basenames(target_name, paths)
headers = sorted(ROOT.glob('App/*.h'))
resources = sorted([*ROOT.glob('Resources/*.xcstrings'), *ROOT.glob('Resources/*Notices.txt'), *ROOT.glob('Resources/PrivacyInfo.xcprivacy'), *ROOT.glob('Resources/SettingsBrandMark.png'), *ROOT.glob('App/Assets.xcassets')])
refs, source_builds, resource_builds = [], [], []
for path in sources + resources + headers:
    relative = str(path.relative_to(ROOT))
    ref = obj(relative, isa='PBXFileReference', lastKnownFileType={'.swift': 'sourcecode.swift', '.metal': 'sourcecode.metal', '.m': 'sourcecode.c.objc', '.h': 'sourcecode.c.h', '.xcprivacy': 'text.xml', '.png': 'image.png', '.xcassets': 'folder.assetcatalog'}.get(path.suffix, 'text.json.xcstrings' if path.suffix == '.xcstrings' else 'text'), path=relative, sourceTree='<group>')
    refs.append(ref)
    if path in headers: continue
    options = {'settings': {'COMPILER_FLAGS': '-fobjc-arc'}} if path.suffix == '.m' else {}
    build = obj('build:'+relative, isa='PBXBuildFile', fileRef=ref, **options)
    (source_builds if path in sources else resource_builds).append(build)
# TestFlight/App Store inputs live in a Release-only layer on top of the debug-safe Base chain.
release_config_ref = obj('release-base', isa='PBXFileReference', lastKnownFileType='text.xcconfig', path='Config/Release.xcconfig', sourceTree='<group>')
# Fail-closed gate: Release builds stop when deployment identity is empty or a placeholder.
# tools/check_release_config.py extracts this exact script and runs it against sample values.
release_gate_script = r'''# Release-only deployment identity gate. Debug and test builds skip it.
[ "${CONFIGURATION}" = "Release" ] || exit 0
fail() { echo "error: Release build blocked: $1 Set it in Config/Release.xcconfig (see docs/release/testflight-internal.md)." >&2; exit 1; }
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
url=$(trim "${QUESTIFY_API_BASE_URL}")
realm=$(trim "${QUESTIFY_SESSION_REALM}")
bundle=$(trim "${PRODUCT_BUNDLE_IDENTIFIER}")
[ -n "$url" ] || fail "QUESTIFY_API_BASE_URL is empty."
case "$url" in https://*) ;; *) fail "QUESTIFY_API_BASE_URL must be an https:// URL." ;; esac
[ -n "$realm" ] || fail "QUESTIFY_SESSION_REALM is empty."
[ -n "$bundle" ] || fail "PRODUCT_BUNDLE_IDENTIFIER is empty."
lower=$(printf '%s' "$bundle" | tr 'A-Z' 'a-z')
case "$lower" in
  invalid.*|*.invalid|*example*|*placeholder*|*changeme*|*todo*|*\$\(*) fail "PRODUCT_BUNDLE_IDENTIFIER '$bundle' is a placeholder." ;;
esac
printf '%s' "$bundle" | grep -Eq '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' || fail "PRODUCT_BUNDLE_IDENTIFIER '$bundle' is not a reverse-DNS identifier."
exit 0
'''
release_gate=obj('release-gate', isa='PBXShellScriptBuildPhase', buildActionMask=2147483647, files=[], inputFileListPaths=[], inputPaths=[], name='Release Identity Gate', outputFileListPaths=[], outputPaths=[], runOnlyForDeploymentPostprocessing=0, shellPath='/bin/sh', shellScript=release_gate_script, alwaysOutOfDate=1)
config_ref = obj('base', isa='PBXFileReference', lastKnownFileType='text.xcconfig', path='Config/Base.xcconfig', sourceTree='<group>')
product = obj('product', isa='PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='Questify.app', sourceTree='BUILT_PRODUCTS_DIR')
products = obj('products', isa='PBXGroup', children=[product], name='Products', sourceTree='<group>')
group = obj('main-group', isa='PBXGroup', children=refs+[config_ref,release_config_ref,products], sourceTree='<group>')
src_phase=obj('sources',isa='PBXSourcesBuildPhase',buildActionMask=2147483647,files=source_builds,runOnlyForDeploymentPostprocessing=0)
res_phase=obj('resources',isa='PBXResourcesBuildPhase',buildActionMask=2147483647,files=resource_builds,runOnlyForDeploymentPostprocessing=0)
# Vendored, immutable official source only. No SwiftPM binary target, package
# resolution, downloaded codecs or build scripts are allowed in this target.
gltf_project=obj('gltf-project',isa='PBXFileReference',lastKnownFileType='wrapper.pb-project',path='Vendor/GLTFKit2/GLTFKit2.xcodeproj',sourceTree='<group>')
objects[group]['children'].append(gltf_project)
gltf_product_proxy=obj('gltf-product-proxy',isa='PBXContainerItemProxy',containerPortal=gltf_project,proxyType=2,remoteGlobalIDString='834FF1C425C27938001887C2',remoteInfo='GLTFKit2')
gltf_product=obj('gltf-product',isa='PBXReferenceProxy',fileType='wrapper.framework',path='GLTFKit2.framework',remoteRef=gltf_product_proxy,sourceTree='BUILT_PRODUCTS_DIR')
gltf_products=obj('gltf-products',isa='PBXGroup',children=[gltf_product],name='Products',sourceTree='<group>')
gltf_target_proxy=obj('gltf-target-proxy',isa='PBXContainerItemProxy',containerPortal=gltf_project,proxyType=1,remoteGlobalIDString='834FF1C325C27938001887C2',remoteInfo='GLTFKit2')
gltf_dependency=obj('gltf-dependency',isa='PBXTargetDependency',name='GLTFKit2',targetProxy=gltf_target_proxy)
gltf_link=obj('gltf-link',isa='PBXBuildFile',fileRef=gltf_product)
gltf_embed=obj('gltf-embed',isa='PBXBuildFile',fileRef=gltf_product,settings={'ATTRIBUTES':['CodeSignOnCopy','RemoveHeadersOnCopy']})
embed_phase=obj('embed-frameworks',isa='PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=10,files=[gltf_embed],name='Embed Frameworks',runOnlyForDeploymentPostprocessing=0)
framework_phase=obj('frameworks',isa='PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[gltf_link],runOnlyForDeploymentPostprocessing=0)
def configurations(scope):
    configs=[]
    for name in ['Debug','Release']:
        settings = {'SDKROOT':'iphoneos','CLANG_ENABLE_MODULES':'YES'} if scope=='project' else {'PRODUCT_NAME':'$(TARGET_NAME)','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SWIFT_EMIT_LOC_STRINGS':'YES'}
        if scope=='target': settings.update({'FRAMEWORK_SEARCH_PATHS':'$(inherited) $(BUILT_PRODUCTS_DIR)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'})
        if scope=='target': settings['SWIFT_OBJC_BRIDGING_HEADER']='$(SRCROOT)/App/Questify-Bridging-Header.h'
        if scope=='target': settings['CODE_SIGN_ENTITLEMENTS']='Config/Questify.entitlements'
        if scope=='target': settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'})
        if scope=='target' and name=='Debug':
            settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG $(inherited)'+METAL_COND
            settings['ENABLE_TESTABILITY']='YES'
        if scope=='target' and name=='Release':
            settings['EXCLUDED_SOURCE_FILE_NAMES']='$(inherited) '+release_excluded_names
            if METAL_ON: settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='$(inherited)'+METAL_COND
        extra={'baseConfigurationReference':release_config_ref if name=='Release' else config_ref} if scope=='target' else {}
        configs.append(obj(scope+name,isa='XCBuildConfiguration',name=name,buildSettings=settings,**extra))
    return obj(scope+'configs',isa='XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
# Widget extension target: Lock Screen and Dynamic Island Live Activity. Same xcconfig chain as the app so the
# version and team match; the bundle ID appends to the app's. No App Group: ActivityKit carries all content state.
la_files,la_resource_files=[],[]
for path in live_activity_sources+live_activity_resources:
    relative=str(path.relative_to(ROOT))
    is_strings=path.suffix=='.xcstrings'
    ref=obj(relative,isa='PBXFileReference',lastKnownFileType='text.json.xcstrings' if is_strings else 'sourcecode.swift',path=relative,sourceTree='<group>')
    if ref not in objects[group]['children']:
        objects[group]['children'].append(ref)
    (la_resource_files if is_strings else la_files).append(obj('build:'+relative,isa='PBXBuildFile',fileRef=ref))
la_product=obj('la-product',isa='PBXFileReference',explicitFileType='wrapper.app-extension',includeInIndex=0,path='QuestifyLiveActivity.appex',sourceTree='BUILT_PRODUCTS_DIR')
objects[products]['children'].append(la_product)
la_configs=[]
for name in ['Debug','Release']:
    settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'$(inherited).LiveActivity','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator',
              'SWIFT_EMIT_LOC_STRINGS':'YES','INFOPLIST_FILE':'LiveActivityWidget/Info.plist','GENERATE_INFOPLIST_FILE':'YES',
              'INFOPLIST_KEY_CFBundleDisplayName':'Questify','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'NO',
              'ASSETCATALOG_COMPILER_APPICON_NAME':'','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES',
              'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
              'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O'}
    if name=='Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG $(inherited)'
    la_configs.append(obj('la'+name,isa='XCBuildConfiguration',name=name,baseConfigurationReference=release_config_ref if name=='Release' else config_ref,buildSettings=settings))
la_config_list=obj('laconfigs',isa='XCConfigurationList',buildConfigurations=la_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
la_sources=obj('la-sources',isa='PBXSourcesBuildPhase',buildActionMask=2147483647,files=la_files,runOnlyForDeploymentPostprocessing=0)
la_resources=obj('la-resources',isa='PBXResourcesBuildPhase',buildActionMask=2147483647,files=la_resource_files,runOnlyForDeploymentPostprocessing=0)
la_frameworks=obj('la-frameworks',isa='PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
la_target=obj('la-target',isa='PBXNativeTarget',buildConfigurationList=la_config_list,buildPhases=[la_sources,la_frameworks,la_resources],buildRules=[],dependencies=[],name='QuestifyLiveActivity',productName='QuestifyLiveActivity',productReference=la_product,productType='com.apple.product-type.app-extension')
la_proxy=obj('la-proxy',isa='PBXContainerItemProxy',containerPortal=ident('project'),proxyType=1,remoteGlobalIDString=la_target,remoteInfo='QuestifyLiveActivity')
la_dependency=obj('la-dependency',isa='PBXTargetDependency',target=la_target,targetProxy=la_proxy)
la_embed=obj('la-embed',isa='PBXBuildFile',fileRef=la_product,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
la_embed_phase=obj('embed-extensions',isa='PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[la_embed],name='Embed Foundation Extensions',runOnlyForDeploymentPostprocessing=0)
target=obj('target',isa='PBXNativeTarget',buildConfigurationList=configurations('target'),buildPhases=[release_gate,src_phase,framework_phase,res_phase,embed_phase,la_embed_phase],buildRules=[],dependencies=[gltf_dependency,la_dependency],name='Questify',productName='Questify',productReference=product,productType='com.apple.product-type.application')
ui_files=[]
for path in ui_source_paths:
    relative=str(path.relative_to(ROOT))
    ref=obj(relative,isa='PBXFileReference',lastKnownFileType='sourcecode.swift',path=relative,sourceTree='<group>')
    objects[group]['children'].append(ref)
    ui_files.append(obj('build:'+relative,isa='PBXBuildFile',fileRef=ref))
ui_product=obj('ui-product',isa='PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path='QuestifyUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
objects[products]['children'].append(ui_product)
ui_configs=[]
for name in ['Debug','Release']:
    ui_configs.append(obj('ui'+name,isa='XCBuildConfiguration',name=name,baseConfigurationReference=config_ref,buildSettings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'invalid.example.questify.ios.uitests','TEST_TARGET_NAME':'Questify','SWIFT_OPTIMIZATION_LEVEL':'-Onone','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'}))
ui_config_list=obj('uiconfigs',isa='XCConfigurationList',buildConfigurations=ui_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
ui_sources=obj('ui-sources',isa='PBXSourcesBuildPhase',buildActionMask=2147483647,files=ui_files,runOnlyForDeploymentPostprocessing=0)
proxy=obj('ui-proxy',isa='PBXContainerItemProxy',containerPortal=ident('project'),proxyType=1,remoteGlobalIDString=target,remoteInfo='Questify')
dependency=obj('ui-dependency',isa='PBXTargetDependency',target=target,targetProxy=proxy)
ui_target=obj('ui-target',isa='PBXNativeTarget',buildConfigurationList=ui_config_list,buildPhases=[ui_sources],buildRules=[],dependencies=[dependency],name='QuestifyUITests',productName='QuestifyUITests',productReference=ui_product,productType='com.apple.product-type.bundle.ui-testing')
# App-hosted XCTest is deliberately separate from the UI-test target and SwiftPM.
unit_config_ref=obj('unit-base',isa='PBXFileReference',lastKnownFileType='text.xcconfig',path='Config/AppUnitTests.xcconfig',sourceTree='<group>')
objects[group]['children'].append(unit_config_ref)
unit_files=[]
for path in unit_source_paths:
    relative=str(path.relative_to(ROOT))
    ref=obj(relative,isa='PBXFileReference',lastKnownFileType='sourcecode.swift',path=relative,sourceTree='<group>')
    # Shared canonical sources reuse their existing reference/build object, but
    # must appear only once in the navigator and once in each target's phase.
    if ref not in objects[group]['children']:
        objects[group]['children'].append(ref)
    unit_files.append(obj('build:'+relative,isa='PBXBuildFile',fileRef=ref))
if not unit_files:
    raise SystemExit('No app-unit sources found; refusing to generate an empty test target')
unit_product=obj('unit-product',isa='PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path='QuestifyAppUnitTests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
objects[products]['children'].append(unit_product)
unit_configs=[obj('unit'+name,isa='XCBuildConfiguration',name=name,baseConfigurationReference=unit_config_ref,
    buildSettings={'PRODUCT_NAME':'$(TARGET_NAME)', **({'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)', 'EXCLUDED_SOURCE_FILE_NAMES':'$(inherited) '+release_test_fixture_names} if name=='Debug' else {})})
    for name in ['Debug','Release']]
unit_config_list=obj('unitconfigs',isa='XCConfigurationList',buildConfigurations=unit_configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Debug')
unit_sources=obj('unit-sources',isa='PBXSourcesBuildPhase',buildActionMask=2147483647,files=unit_files,runOnlyForDeploymentPostprocessing=0)
unit_frameworks=obj('unit-frameworks',isa='PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
unit_proxy=obj('unit-proxy',isa='PBXContainerItemProxy',containerPortal=ident('project'),proxyType=1,remoteGlobalIDString=target,remoteInfo='Questify')
unit_dependency=obj('unit-dependency',isa='PBXTargetDependency',target=target,targetProxy=unit_proxy)
unit_target=obj('unit-target',isa='PBXNativeTarget',buildConfigurationList=unit_config_list,buildPhases=[unit_sources,unit_frameworks],buildRules=[],dependencies=[unit_dependency],name='QuestifyAppUnitTests',productName='QuestifyAppUnitTests',productReference=unit_product,productType='com.apple.product-type.bundle.unit-test')
project=obj('project',isa='PBXProject',attributes={'LastUpgradeCheck':'1500','TargetAttributes':{ui_target:{'TestTargetID':target},unit_target:{'TestTargetID':target}}},buildConfigurationList=configurations('project'),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','zh-Hans','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',projectReferences=[{'ProductGroup':gltf_products,'ProjectRef':gltf_project}],targets=[target,ui_target,unit_target,la_target])
# OpenStep property list, all strings quoted for deterministic escaping.
def serialize(value, level=0):
    if isinstance(value,dict): return '{\n'+''.join('\t'*(level+1)+json.dumps(k)+' = '+serialize(v,level+1)+';\n' for k,v in value.items())+'\t'*level+'}'
    if isinstance(value,list): return '(\n'+''.join('\t'*(level+1)+serialize(v,level+1)+',\n' for v in value)+'\t'*level+')'
    return str(value) if isinstance(value,int) else json.dumps(value,ensure_ascii=False)
folder=ROOT/'Questify.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
def stable_uuid(name):
    digest=hashlib.sha256(name.encode()).hexdigest()
    return f'{digest[0:8]}-{digest[8:12]}-{digest[12:16]}-{digest[16:20]}-{digest[20:32]}'.upper()
scheme=ET.Element('Scheme',LastUpgradeVersion='1500',version='1.3')
entry={'BuildableIdentifier':'primary','BlueprintIdentifier':target,'BuildableName':'Questify.app','BlueprintName':'Questify','ReferencedContainer':'container:Questify.xcodeproj'}
ui_entry={'BuildableIdentifier':'primary','BlueprintIdentifier':ui_target,'BuildableName':'QuestifyUITests.xctest','BlueprintName':'QuestifyUITests','ReferencedContainer':'container:Questify.xcodeproj'}
unit_entry={'BuildableIdentifier':'primary','BlueprintIdentifier':unit_target,'BuildableName':'QuestifyAppUnitTests.xctest','BlueprintName':'QuestifyAppUnitTests','ReferencedContainer':'container:Questify.xcodeproj'}
b=ET.SubElement(scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES')
entries=ET.SubElement(b,'BuildActionEntries')
e=ET.SubElement(entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='YES',buildForProfiling='YES',buildForArchiving='YES',buildForAnalyzing='YES')
ET.SubElement(e,'BuildableReference',**entry)
# Test-only. A plain Build action does not build these bundles.
for reference in (ui_entry, unit_entry):
    test_build=ET.SubElement(entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='NO',buildForProfiling='NO',buildForArchiving='NO',buildForAnalyzing='NO')
    ET.SubElement(test_build,'BuildableReference',**reference)
# Xcode Cloud Test iOS uses this scheme. One shared plan runs every app-unit
# class (the four shard plans still partition that set) and keeps UI tests.
test_action=ET.SubElement(scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='YES')
ET.SubElement(ET.SubElement(test_action,'TestPlans'),'TestPlanReference',reference='container:Questify.xcodeproj/xcshareddata/xctestplans/QuestifyAppUnitTests-Shards.xctestplan',default='YES')
l=ET.SubElement(scheme,'LaunchAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',launchStyle='0',useCustomWorkingDirectory='NO',ignoresPersistentStateOnLaunch='NO',debugDocumentVersioning='YES',debugServiceExtension='internal',allowLocationSimulation='YES')
ET.SubElement(ET.SubElement(l,'BuildableProductRunnable',runnableDebuggingMode='0'),'BuildableReference',**entry)
ET.SubElement(scheme,'AnalyzeAction',buildConfiguration='Debug')
ET.SubElement(scheme,'ArchiveAction',buildConfiguration='Release',revealArchiveInOrganizer='YES')
scheme_dir=folder/'xcshareddata/xcschemes';scheme_dir.mkdir(parents=True,exist_ok=True)
ET.indent(scheme)
ET.ElementTree(scheme).write(scheme_dir/'Questify.xcscheme',encoding='utf-8',xml_declaration=True)
questify_plan_dir=folder/'xcshareddata/xctestplans';questify_plan_dir.mkdir(parents=True,exist_ok=True)
questify_shards_plan={
    'configurations':[{'id':stable_uuid('xctestplan-config:QuestifyAppUnitTests-Shards'),'name':'Test Scheme Action','options':{}}],
    'defaultOptions':{'targetForVariableExpansion':{'containerPath':'container:Questify.xcodeproj','identifier':target,'name':'Questify'}},
    'testTargets':[
        {'parallelizable':False,'skippedTests':[],'target':{'containerPath':'container:Questify.xcodeproj','identifier':unit_target,'name':'QuestifyAppUnitTests'}},
        {'parallelizable':False,'skippedTests':[],'target':{'containerPath':'container:Questify.xcodeproj','identifier':ui_target,'name':'QuestifyUITests'}},
    ],
    'version':1,
}
(questify_plan_dir/'QuestifyAppUnitTests-Shards.xctestplan').write_text(json.dumps(questify_shards_plan,indent=2)+'\n')
print(f'Generated Questify.xcodeproj: {len(sources)} native sources, {len(resources)} catalogs')

# Dedicated shared scheme still runs the whole app-unit target and skips nothing.
unit_scheme=ET.Element('Scheme',LastUpgradeVersion='1500',version='1.3')
unit_build=ET.SubElement(unit_scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES')
unit_entries=ET.SubElement(unit_build,'BuildActionEntries')
for reference in [entry,unit_entry]:
    build=ET.SubElement(unit_entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='NO',buildForProfiling='NO',buildForArchiving='NO',buildForAnalyzing='NO')
    ET.SubElement(build,'BuildableReference',**reference)
unit_action=ET.SubElement(unit_scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='NO')
ET.SubElement(ET.SubElement(unit_action,'MacroExpansion'),'BuildableReference',**entry)
unit_testable=ET.SubElement(ET.SubElement(unit_action,'Testables'),'TestableReference',skipped='NO',parallelizable='NO')
ET.SubElement(unit_testable,'BuildableReference',**unit_entry)
ET.indent(unit_scheme)
ET.ElementTree(unit_scheme).write(scheme_dir/'QuestifyAppUnitTests.xcscheme',encoding='utf-8',xml_declaration=True)
print(f'Included {len(unit_files)} app-unit sources in the separate QuestifyAppUnitTests scheme')

# The unfiltered QuestifyAppUnitTests scheme above stays complete. These extra
# plans only partition that same target; every discovered class stays in exactly
# one shard. The Questify scheme plan does not skip any of them.
APP_UNIT_CLASS=re.compile(r'(?m)^(?:@\w+(?:\([^)\n]*\))?\s+)*(?:(?:public|internal|fileprivate|private|final|open|nonisolated)\s+)*class\s+([A-Za-z_][A-Za-z0-9_]*)\b[^{;\n]*\bXCTestCase\b')
APP_UNIT_SHARDS=4
def app_unit_classes():
    found=[]
    for path in sorted(ROOT.glob('Tests/AppUnitTests/**/*.swift')):
        found.extend(APP_UNIT_CLASS.findall(path.read_text()))
    if len(found)!=len(set(found)):
        raise SystemExit('App-unit XCTest classes must be present and unique')
    return found
def shard_of(name):
    return int(hashlib.sha256(name.encode()).hexdigest(),16)%APP_UNIT_SHARDS
classes=app_unit_classes()
# Synthetic generator fixtures have no XCTestCase classes. The real tree still
# refuses duplicate names and an empty shard once any class is present.
if classes:
    groups=[[] for _ in range(APP_UNIT_SHARDS)]
    for name in classes: groups[shard_of(name)].append(name)
    if any(not group for group in groups): raise SystemExit('Refusing an empty app-unit shard')
    plan_dir=folder/'xcshareddata/xctestplans'; plan_dir.mkdir(parents=True,exist_ok=True)
    for index,group in enumerate(groups,start=1):
        label=f'Shard{index:02d}'
        included=set(group)
        plan={
            'configurations':[{'id':stable_uuid('xctestplan-config:'+label),'name':'Test Scheme Action','options':{}}],
            'defaultOptions':{'targetForVariableExpansion':{'containerPath':'container:Questify.xcodeproj','identifier':target,'name':'Questify'}},
            'testTargets':[{
                'parallelizable':False,
                'skippedTests':sorted(name for name in classes if name not in included),
                'target':{'containerPath':'container:Questify.xcodeproj','identifier':unit_target,'name':'QuestifyAppUnitTests'},
            }],
            'version':1,
        }
        plan_name=f'QuestifyAppUnitTests-{label}.xctestplan'
        (plan_dir/plan_name).write_text(json.dumps(plan,indent=2)+'\n')
        shard_scheme=ET.Element('Scheme',LastUpgradeVersion='1500',version='1.3')
        shard_build=ET.SubElement(shard_scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES')
        shard_entries=ET.SubElement(shard_build,'BuildActionEntries')
        for reference in [entry,unit_entry]:
            build=ET.SubElement(shard_entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='NO',buildForProfiling='NO',buildForArchiving='NO',buildForAnalyzing='NO')
            ET.SubElement(build,'BuildableReference',**reference)
        shard_action=ET.SubElement(shard_scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='NO')
        ET.SubElement(ET.SubElement(shard_action,'MacroExpansion'),'BuildableReference',**entry)
        ET.SubElement(ET.SubElement(shard_action,'TestPlans'),'TestPlanReference',reference='container:Questify.xcodeproj/xcshareddata/xctestplans/'+plan_name,default='YES')
        ET.indent(shard_scheme)
        ET.ElementTree(shard_scheme).write(scheme_dir/f'QuestifyAppUnitTests-{label}.xcscheme',encoding='utf-8',xml_declaration=True)
    print(f'Wrote {APP_UNIT_SHARDS} shared app-unit shards covering {len(classes)} classes: '+', '.join(f'{len(group)}' for group in groups))
