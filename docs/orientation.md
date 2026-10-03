# Orientation

A short guide to the project for reviewing the Swift work in later tickets. Read it once with Xcode open
next to it.

## Project layout

```
Dueboard.xcodeproj/            The Xcode project: one app target and the shared Dueboard scheme
Dueboard/                      The app: SwiftUI screens and, later, the CloudKit and notification adapters
  DueboardApp.swift            The entry point (@main); builds the Household and shows the first screen
  PlaceholderView.swift        Stands in for the Month board until the screens ticket
  Assets.xcassets              App icon and accent colour
Packages/HouseholdCore/        The household core, a Swift package of its own
  Package.swift                Declares the HouseholdCore library and its test target
  Sources/HouseholdCore/       Every domain rule from CONTEXT.md, in plain Swift
  Tests/HouseholdCoreTests/    Swift Testing tests of the core
CONTEXT.md                     The glossary; the code uses these words
docs/xcode-cloud.md            How Xcode Cloud builds, tests and uploads to TestFlight
```

The app depends on the core, never the other way round. Swift enforces this: the core is a separate
package that does not know the app exists, so the core cannot call into the app even by mistake. The core
also imports only `Foundation`: no SwiftUI, CloudKit or UserNotifications.

The `Dueboard/` folder is a synchronized folder: any file put in it is part of the app, with no need to add
it to the project by hand. Files added to the core's `Sources` or `Tests` folders are picked up the same way,
because Swift packages find their files by folder.

## Running the app

1. `open Dueboard.xcodeproj`.
2. In the toolbar at the top, the scheme menu should read **Dueboard**. Next to it is the run destination:
   pick an iPhone simulator, for example iPhone 17.
3. Press **Cmd-R** (Product > Run). The Simulator opens and shows "Dueboard" with the current month under it.
   **Cmd-.** stops it.

The deployment target is iOS 18.0, so the app runs on iOS 18 and every later version. The newest
Simulator that comes with Xcode runs the newest iOS. To try iOS 18 itself, add an iOS 18 runtime under
Xcode > Settings > Components, then create an iPhone simulator on it under Window > Devices and Simulators.

### On a cabled iPhone

1. Connect the phone with a cable and unlock it; accept "Trust This Computer" on the phone.
2. The first time: on the phone, turn on Settings > Privacy & Security > Developer Mode and restart it.
   The switch only appears after the phone has been connected to Xcode once.
3. In Xcode, select the **Dueboard** project in the navigator, then the **Dueboard** target, then the
   **Signing & Capabilities** tab. Keep "Automatically manage signing" on and pick your team. If no team is
   listed, sign in under Xcode > Settings > Accounts. Any Apple ID works: without the paid developer
   account it shows up as a "Personal Team", which is enough to run on your own phone (the app then stops
   opening after 7 days until you run it from Xcode again). iCloud sync will need the paid team.
4. Pick the phone as the run destination and press **Cmd-R**.

If Xcode 26 says it does not support the phone's iOS version, the phone gets the app through TestFlight
once Xcode Cloud is set up, and the Simulator stays the everyday test device.

## Running the tests

- **In Xcode**: **Cmd-U** (Product > Test) builds the scheme and runs every test on the selected
  simulator. The Test navigator (**Cmd-6**) lists each test with a diamond next to it; click a diamond to
  run just that test or suite. Diamonds also show up in the editor's gutter beside each `@Test`.
- **From the command line**, on the Mac, without a Simulator. This is the fastest loop:

  ```sh
  swift test --package-path Packages/HouseholdCore
  swift test --package-path Packages/HouseholdCore --filter BillingMonthTests   # only the suites or test functions whose Swift name matches
  ```

- **From the command line through Xcode**, the way Xcode Cloud will run them:

  ```sh
  xcodebuild test -project Dueboard.xcodeproj -scheme Dueboard \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```

Tests use [Swift Testing](https://developer.apple.com/documentation/testing): a test is a function
marked `@Test("what it checks, in words")`, grouped in a `@Suite`. `#expect(a == b)` checks a value and
the test carries on if it fails; `try #require(...)` stops the test when it fails, and is used to unwrap
something the rest of the test needs. Test names are sentences in the glossary's words, so the test list
reads as the rules of the app.

## Reading a SwiftUI view

`PlaceholderView.swift`, slightly trimmed:

```swift
struct PlaceholderView: View {          // a screen, or part of one, is a struct that conforms to View
    let month: BillingMonth             // its input, passed in by whoever shows it

    var body: some View {               // what to draw; SwiftUI calls this whenever the input changes
        VStack(spacing: 8) {            // stack the children top to bottom, 8 points apart
            Text("Dueboard")
                .font(.largeTitle.bold())   // modifiers: each one wraps the view and returns a new one
            Text(title)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {                              // what Xcode's canvas shows; never part of the running app
    PlaceholderView(month: BillingMonth(year: 2026, month: 9))
}
```

Things to know when reviewing a view:

- A view describes what the screen looks like for its current input; it does not change the screen step
  by step. When the input changes, SwiftUI calls `body` again and updates what changed.
- `VStack` stacks vertically, `HStack` horizontally, `List` makes a scrolling table, `Section` groups rows.
- Modifiers read top to bottom, and their order matters: `.padding().background(.red)` colours the
  padding too, `.background(.red).padding()` does not.
- `@State` marks a value the view owns and can change (a text being typed); `@Binding` is a value owned by
  a parent that the view may change. Neither appears yet.
- The **canvas** (Editor > Canvas, or **Cmd-Option-Return**) renders the `#Preview` live next to the code.
- What to look for in review: a view should only show what the core returns and send commands to it. Any
  `if` that decides a domain rule (is this Due Overdue? can this Bill be added?) belongs in the core, with
  a test.

## How the core seam works

The household core is the one place every domain rule lives, and the one place tests run against. Screens
send it commands and show what it returns; they hold no rules of their own.

Today the core is just enough to show the shape:

```swift
public struct Household {
    public init(clock: WallClock)
    public var currentBillingMonth: BillingMonth { get }
}
```

**The clock is injected.** The core never asks the device for the date or the time zone itself. Whoever
creates a `Household` hands it a `WallClock`, which supplies `now` and the `timeZone`:

- The app passes `.system`: the device's real time and its time zone, following the phone when it
  travels (`DueboardApp.swift`).
- Tests pass `.fixed(date, in: timeZone)`: a clock stopped at a chosen moment and place. This is what makes
  date rules testable. `BillingMonthTests.swift` pins the clock to 02:00 UTC on October 1 in New York,
  where it is still September 30, and checks that the current Billing Month is September.

**Tests go through the public interface only.** A test builds a `Household`, sends it commands and checks
what comes back, the same way a screen would. It never reads private state or stored records, so how the
core stores things can change without breaking a test. `import HouseholdCore` (not
`@testable import`) keeps tests honest: they can only see what is `public`.

**What comes next**: later tickets grow this same interface. Commands such as add a Bill, open a Billing
Month or mark a Due Paid; outputs such as the Month board, the Bills list, refusals with readable reasons
and the reminder plan. Storage (Core Data with CloudKit) and notifications plug in as adapters in the app,
outside the core.

**`public`**: Swift hides everything in a module from other modules unless it is marked `public`. The
app and the tests are other modules, so in the core `public` marks the interface they may use, and anything
without it is an internal detail.
