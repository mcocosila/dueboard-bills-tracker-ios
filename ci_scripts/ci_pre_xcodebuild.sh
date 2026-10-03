#!/bin/sh
# Xcode Cloud runs this before each xcodebuild action. The Archive action runs
# alongside the Test action, not after it, and uploads to TestFlight as soon as
# it ends; so before archiving, run the household core's tests, and a failing
# test stops the archive before anything is uploaded.
set -eu

if [ "$CI_XCODEBUILD_ACTION" = "archive" ]; then
    swift test --package-path "$CI_PRIMARY_REPOSITORY_PATH/Packages/HouseholdCore"
fi
