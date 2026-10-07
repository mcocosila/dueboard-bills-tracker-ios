# Xcode Cloud

Xcode Cloud builds, tests and uploads every TestFlight and App Store build of Dueboard on Apple's machines,
with the latest Xcode release. Nothing is archived or uploaded from the Mac: the Mac is Intel and runs
Xcode 26 at most, and from April 2027 App Store Connect accepts only builds made with the iOS 27 SDK.

The workflows live in App Store Connect, not in this repo. This page records how they are set up, so they
can be checked or rebuilt.

## The two workflows

| | Build and Test | TestFlight |
|---|---|---|
| Starts on | a push to any branch, and any pull request | a push to `main` |
| Xcode and macOS | Latest Release | Latest Release |
| Actions | Test (iOS) | Test (iOS); Archive (iOS), prepared for TestFlight and App Store |
| Clean build | off | off (only builds for external testers need one) |

Both use the shared `Dueboard` scheme, whose test action runs the household core's tests on an iPhone 17
simulator with the newest iOS of the selected Xcode. Every action is Required To Pass.

## A failing test stops the upload

Xcode Cloud runs a workflow's actions side by side, not one after another, and the Archive action uploads
to App Store Connect as soon as it ends. Required To Pass only marks the run failed; by then the archive is
uploaded. So the gate is in the repo: [`ci_scripts/ci_pre_xcodebuild.sh`](../ci_scripts/ci_pre_xcodebuild.sh)
runs before each action, and before the Archive action it runs the core's tests with `swift test`. A
failing test fails the script, the archive never starts, and nothing is uploaded.

This was checked on 3 October 2026 with a throwaway `ci-red` branch whose only commit broke a test: before
the script, run 5 failed at Test but its archive still reached TestFlight as build 5.

## Testers

TestFlight's internal group **Developers** has access to all builds, so every build Xcode Cloud uploads is
offered to it with no post-action. The partner is added in the first TestFlight ticket (#14).

## Numbers and keys

Xcode Cloud numbers its runs 1, 2, 3 and so on and stamps that number on the app as its build number, so
`CURRENT_PROJECT_VERSION` in the project is never changed by hand. The version (`MARKETING_VERSION`, now
0.1) is raised by hand when a release needs it. A run that uploads nothing still uses up its number.

The app declares `ITSAppUsesNonExemptEncryption = NO` (it uses only the encryption built into iOS), so
TestFlight does not hold each build waiting for an export compliance answer.

A push to `main`, or to a branch with an open pull request, starts two runs and tests twice. That is a few
minutes of the 25 compute hours a month, and Auto-cancel Builds drops a run that a newer push has made stale.

## iCloud

The app's entitlements (`Dueboard/Dueboard.entitlements`) name the iCloud container
`iCloud.com.neodonis.dueboard` and push, with `aps-environment` set to `development`; the Archive action's
distribution signing turns that into `production` on its own. A TestFlight build syncs through CloudKit's
Production environment, so the CloudKit schema has to be deployed to Production in the CloudKit Console before
a TestFlight build can sync, and again after any model change that adds a field. Production only ever grows:
nothing in the model is renamed or removed once deployed.

## How it was set up

1. In Xcode, Integrate > Create Workflow, accepting the suggested workflow, and granting Xcode Cloud access
   to GitHub: the Xcode Cloud GitHub app is installed on `mcocosila/dueboard-bills-tracker-ios` only. Only
   this step needs Xcode; the App Store Connect API cannot create the Xcode Cloud product or connect GitHub.
2. Everything else went through the App Store Connect API with a team key (Admin role): the suggested
   workflow became TestFlight, Build and Test was created, and the Developers group was created with access
   to all builds. The same changes can be made by hand under the app's Xcode Cloud tab in App Store
   Connect, or in Xcode under Integrate > Manage Workflows.

To start a TestFlight run on a branch other than `main`, add the branch to the workflow's manual start
condition first; Xcode Cloud refuses a manual run on a branch the workflow does not list.
