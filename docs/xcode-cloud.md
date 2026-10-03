# Xcode Cloud

Xcode Cloud builds, tests and uploads every TestFlight and App Store build of Dueboard on Apple's machines,
with the latest Xcode release. Nothing is archived or uploaded from the Mac: the Mac is Intel and runs
Xcode 26 at most, and from April 2027 App Store Connect accepts only builds made with the iOS 27 SDK.

The workflows live in App Store Connect, not in this repo. This page records how they are set up, so they
can be checked or rebuilt by hand.

## The two workflows

| | Build and Test | TestFlight |
|---|---|---|
| Starts on | a push to any branch, and any pull request | a push to `main` |
| Xcode | Latest Release | Latest Release |
| Actions | Test (iOS), Required To Pass | Test (iOS), Required To Pass; Archive (iOS) |
| Post-action | none | TestFlight Internal Testing, group **Developers** |

Both use the shared `Dueboard` scheme, whose test action runs the household core's tests. A test that
fails fails the build, and Xcode Cloud runs the TestFlight post-action only for a build that succeeded, so a
failing test stops the upload.

Xcode Cloud numbers its builds 1, 2, 3 and so on and stamps that number on the app as its build number,
so `CURRENT_PROJECT_VERSION` in the project is never changed by hand. The version (`MARKETING_VERSION`,
now 0.1) is raised by hand when a release needs it.

The app declares `ITSAppUsesNonExemptEncryption = NO` (it uses only the encryption built into iOS), so
TestFlight does not hold each build waiting for an export compliance answer.

## One-time setup

The first workflow has to be made in Xcode; after the first build, workflows can also be edited in App
Store Connect under the app's Xcode Cloud tab. Xcode 26 on the Mac is enough to create them, since the
build itself runs on Apple's machines with whatever Xcode the workflow names.

1. **Internal testers.** In App Store Connect, open Dueboard > TestFlight, add an internal group named
   **Developers**, and add yourself. The partner joins in the first TestFlight ticket.
2. **Create the first workflow.** In Xcode, open the project and choose Integrate > Create Workflow (or
   the Cloud tab of the Report navigator), pick the `Dueboard` app, then Edit Workflow.
   - Name: **Build and Test**.
   - Environment: Xcode version **Latest Release**, macOS **Latest Release**. Leave Clean off.
   - Start conditions: change the suggested Branch Changes condition to **Any Branch**, and add a
     **Pull Request Changes** condition with any source and any target branch.
   - Actions: remove the suggested Archive action. Add a **Test** action: platform iOS, scheme
     `Dueboard`, destination iOS Simulator (Recommended iPhones), **Required To Pass**.
   - Post-actions: none.
3. **Grant access to GitHub.** Xcode asks for it after the workflow is saved: install the Xcode Cloud
   GitHub app on `mcocosila/dueboard-bills-tracker-ios` only. Xcode finds the existing app record.
4. **Start the first build** on `main` and wait for it to pass.
5. **Create the TestFlight workflow** (Integrate > Manage Workflows > +, or in App Store Connect):
   - Name: **TestFlight**.
   - Environment: Xcode **Latest Release**, macOS **Latest Release**.
   - Start condition: **Branch Changes**, custom branch `main` only. Remove any pull request condition.
   - Actions: a **Test** action set up as in Build and Test, **Required To Pass**; and an **Archive**
     action, platform iOS, deployment preparation **TestFlight and App Store**, so the same build can
     later be submitted for review.
   - Post-action: **TestFlight Internal Testing**, group **Developers**.
6. **Push to `main`** (or Start Build on the TestFlight workflow) and check:
   - both workflows run and pass in App Store Connect > Xcode Cloud;
   - the build shows in TestFlight as 0.1 (N), where N is the Xcode Cloud build number, and is
     available to the Developers group;
   - Xcode Cloud reports each run as a check on the GitHub commit or pull request.

To prove a failing test stops the upload, push a branch whose first commit breaks a test, merge it to
`main`, check that the TestFlight build fails at Test and no new build reaches TestFlight, then revert.
