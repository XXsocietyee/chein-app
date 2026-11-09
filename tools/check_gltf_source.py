#!/usr/bin/env python3
"""Offline audit of pinned GLTFKit2 source; does not fetch or execute dependencies."""
import hashlib,json,pathlib,re,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
VENDOR=ROOT/'Vendor/GLTFKit2'
pin=json.loads((VENDOR/'PROVENANCE.json').read_text())
assert pin['revision']=='e69e354c4f31ea07b7816b8cbe2ddb28e897d073'
assert pin['sourceOnly'] is True
def git_blob(raw):
    return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
# Upstream GLTFKit2 sets IPHONEOS_DEPLOYMENT_TARGET = 12.1. The vendored
# project keeps every other byte and sets 17.0 so a fresh checkout matches the
# app target. No CI script rewrites this file.
project_path=VENDOR/'GLTFKit2.xcodeproj/project.pbxproj'
project_bytes=project_path.read_bytes()
upstream_project=project_bytes.replace(
    b'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    b'IPHONEOS_DEPLOYMENT_TARGET = 12.1;')
assert upstream_project!=project_bytes,'GLTFKit2 iOS deployment target was not raised to 17.0'
assert upstream_project.count(b'IPHONEOS_DEPLOYMENT_TARGET = 12.1;')==2
assert b'IPHONEOS_DEPLOYMENT_TARGET = 17.0;' not in upstream_project
for row in pin['files']:
    raw=(VENDOR/row['path']).read_bytes()
    if row['path']=='GLTFKit2.xcodeproj/project.pbxproj':
        raw=upstream_project
    assert hashlib.sha256(raw).hexdigest()==row['sha256'],row['path']
    assert git_blob(raw)==row['gitBlob'],row['path']
project=project_bytes.decode()
for forbidden in ['PBXShellScriptBuildPhase','XCRemoteSwiftPackageReference','ktx.xcframework','GLTF_BUILD_WITH_KTX2']:
    assert forbidden not in project,forbidden
for path in VENDOR.rglob('*'):
    assert path.suffix not in ['.a','.dylib','.zip','.xcframework'],path
notices=(ROOT/'Resources/GLTFKit2Notices.txt').read_text()
for author in ['Warren Moore','Johannes Kuhlmann','Serge A. Zaitsev']:assert author in notices
app=(ROOT/'App/PlayKitGLBAssets.swift').read_text()
assert 'import GLTFKit2' in app and 'canImport(GLTFKit2)' not in app
assert 'GLTFAsset.load(with: data' in app
print(f'PASS: {len(pin["files"])} official source files match immutable Git blobs and SHA256; MIT notices present; no optional binary codecs/scripts')
