#!/bin/sh
# Xcode Cloud runs this after clone. The committed Questify project and shared
# Questify scheme already match tools/generate_project.py, so a fresh checkout
# builds without generating the project. This script only disables signing on
# the temporary checkout. It does not rewrite the GLTFKit2 deployment target:
# that project is already iOS 17.0, and tools/check_gltf_source.py allows only
# that change from the upstream pin.
set -eu
cd "${CI_PRIMARY_REPOSITORY_PATH}"
python3 tools/xcode_cloud_prepare.py --checkout "${CI_PRIMARY_REPOSITORY_PATH}"
