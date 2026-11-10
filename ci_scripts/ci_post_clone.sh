#!/bin/sh
# Xcode Cloud runs this after clone. The committed Questify project and shared
# Questify scheme already match tools/generate_project.py, so a fresh checkout
# builds without generating the project. This script disables signing on the
# temporary checkout and writes a CI-only simulator architecture xcconfig.
# It does not rewrite the GLTFKit2 deployment target: that project is already
# iOS 17.0, and tools/check_gltf_source.py allows only that change from the
# upstream pin.
#
# The xcconfig is not applied. xcodebuild loads XCODE_XCCONFIG_FILE for every
# target only when that variable is already in the xcodebuild process.
# Xcode Cloud starts that process after this script exits, and exporting the
# variable here does not carry over. The Questify scheme Test action has no
# xcconfig attribute. Setting the variable is a workflow Environment edit.
# This script does not edit the workflow.
set -eu
cd "${CI_PRIMARY_REPOSITORY_PATH}"
python3 tools/xcode_cloud_prepare.py --checkout "${CI_PRIMARY_REPOSITORY_PATH}"
mkdir -p "${CI_PRIMARY_REPOSITORY_PATH}/ci_scripts"
cat > "${CI_PRIMARY_REPOSITORY_PATH}/ci_scripts/ci-simulator-arch.xcconfig" <<'EOF'
// CI-only. ci_scripts/ci_post_clone.sh writes this file on the temporary checkout.
// The Questify scheme Test action does not reference it.
ARCHS = arm64
EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64
ONLY_ACTIVE_ARCH = YES
EOF
echo "Wrote ${CI_PRIMARY_REPOSITORY_PATH}/ci_scripts/ci-simulator-arch.xcconfig (ARCHS=arm64, EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64, ONLY_ACTIVE_ARCH=YES). The Test action does not load it."
