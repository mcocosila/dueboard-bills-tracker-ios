# Dueboard: Bills Tracker

An iPhone app: a shared monthly checklist so every household bill is paid before its due date. Data lives on
the phone and syncs through iCloud; a household is shared with an iCloud invite. Vocabulary is in
[CONTEXT.md](CONTEXT.md).

It replaces the Django web app in the private repo `mcocosila/pay-bills-tracker`, which is
retired once this app has run a full Billing Month on TestFlight.
Its pytest suite is the reference for the household core's tests: every domain test there gets a Swift
counterpart. Read it with `gh repo clone mcocosila/pay-bills-tracker` (needs access to the private repo).

## Build, run and test

Needs Xcode 26, which runs on macOS 15.6 or later. The orientation guide, [docs/orientation.md](docs/orientation.md), explains
each step in more detail.

- **Open**: `open Dueboard.xcodeproj`. Xcode resolves the local `HouseholdCore` package on its own.
- **Run in the Simulator**: pick the `Dueboard` scheme and an iPhone simulator in the toolbar, then
  press Cmd-R.
- **Run on a cabled iPhone**: plug the phone in, pick it as the run destination, choose your team (a free
  Apple ID's Personal Team is enough) under the `Dueboard` target's Signing & Capabilities, then press Cmd-R.
- **Test in Xcode**: Cmd-U runs the household core's tests.
- **Test from the command line**, either of:

  ```sh
  # Fast: runs the core's tests on the Mac, no Simulator
  swift test --package-path Packages/HouseholdCore

  # The same tests through Xcode on a Simulator, the way Xcode Cloud runs them
  xcodebuild test -project Dueboard.xcodeproj -scheme Dueboard \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```
