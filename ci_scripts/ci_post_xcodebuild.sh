#!/bin/sh
# Core tests live in the Swift package (Package.swift, QuestifyCoreTests), not
# in an Xcode test target. Run them once, with the source checkout, on the
# Build action for the Questify scheme. Shard test actions and a later Archive
# action do not repeat them. The test-without-building phase has no source.
set -eu
if [ "${CI_XCODEBUILD_ACTION}" = "build" ] && [ "${CI_XCODE_SCHEME}" = "Questify" ]; then
  cd "${CI_PRIMARY_REPOSITORY_PATH}"
  swift test
fi
