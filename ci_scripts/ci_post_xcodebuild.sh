#!/bin/sh
# Core tests live in the Swift package (Package.swift, QuestifyCoreTests), not
# in an Xcode test target. Run them once, with the source checkout, on the
# Build action for the Questify scheme. Shard test actions and a later Archive
# action do not repeat them. The test-without-building phase has no source.
# This script must not fail the Xcode Cloud build. A non-zero xcodebuild status
# skips swift test. swift test's own status is ignored. Always exit 0.
set +e
xcodebuild_exit_code="${CI_XCODEBUILD_EXIT_CODE:-0}"
if [ "${xcodebuild_exit_code}" -eq 0 ] \
  && [ "${CI_XCODEBUILD_ACTION}" = "build" ] \
  && [ "${CI_XCODE_SCHEME}" = "Questify" ]; then
  cd "${CI_PRIMARY_REPOSITORY_PATH}"
  swift test
fi
exit 0
