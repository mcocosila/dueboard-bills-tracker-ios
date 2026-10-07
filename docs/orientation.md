# Orientation

A short guide to the project for reviewing the Swift work in later tickets. Read it once with Xcode open
next to it.

## Project layout

```
Dueboard.xcodeproj/            The Xcode project: one app target and the shared Dueboard scheme
Dueboard/                      The app: SwiftUI screens, the notification adapter and the CloudKit adapter
  DueboardApp.swift            The entry point (@main); opens the Household, reads it again after a change synced
                               from another device, shares it, joins an accepted invite, and shows the first screen
  Sharing.swift                Where accepted invites arrive (the scene delegate), iCloud's sharing screen, and
                               the line shown while an invite's Household is on its way
  RootView.swift               The tabs: the Billing Month and the Bills; keeps the notifications matching the
                               reminder plan and asks for permission the first time there is a Reminder
  ICloudAccount.swift          Whether the phone is signed in to iCloud, and the line shown when it is not
  ReminderNotifications.swift  The notification adapter: makes the pending notifications match the reminder
                               plan, and opens the Billing Month of a tapped notification
  MonthView.swift              The Month board: a Billing Month's Dues by Category, stepping between months,
                               adding a Bill to the month and removing a Due
  BillsView.swift              The Bills list, grouped by Category, with the Retired Bills last
  BillFormView.swift           The form for adding or editing a Bill, and Retiring or reactivating it
  CategoriesView.swift         Creating, renaming, reordering and deleting Categories, from the Bills tab
  CoreDataHouseholdStore.swift Keeps the Household in Core Data on the phone and syncs it through iCloud
  CoreDataHouseholdStore+Sharing.swift
                               Shares the Household with a CloudKit share, accepts an invite, and takes a
                               Household the Member left off the phone
  Duplicates.swift             Which copy stays when two devices made the same record before they synced
  Dueboard.xcdatamodeld        The Core Data model, one version per change: Household, Category, Bill,
                               Billing Month and Due
  Dueboard.entitlements        iCloud (CloudKit, container iCloud.com.neodonis.dueboard) and push, which
                               CloudKit uses to tell the app a change is waiting
  Info.plist                   Only the keys Xcode cannot generate from build settings: the remote
                               notification background mode, so a sync can arrive while the app is not open,
                               and CKSharingSupported, so tapping an invite opens Dueboard
  Assets.xcassets              App icon and accent colour
Packages/HouseholdCore/        The household core, a Swift package of its own
  Package.swift                Declares the HouseholdCore library and its test target
  Sources/HouseholdCore/       Every domain rule from GLOSSARY.md, in plain Swift
  Tests/HouseholdCoreTests/    Swift Testing tests of the core
GLOSSARY.md                    The glossary; the code uses these words
docs/xcode-cloud.md            How Xcode Cloud builds, tests and uploads to TestFlight
docs/manual-checklist.md       What automated tests cannot cover, checked by hand on every TestFlight build
ci_scripts/                    Scripts Xcode Cloud runs during a build: tests before every archive
scripts/draw-app-icon.swift    Draws the app icon; rerun from the repo root with swift scripts/draw-app-icon.swift
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
3. Press **Cmd-R** (Product > Run). The Simulator opens on the Month tab, titled with the current month.
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

`DueRow` from `MonthView.swift`, slightly trimmed:

```swift
private struct DueRow: View {           // a screen, or part of one, is a struct that conforms to View
    let due: Due                        // its input, passed in by whoever shows it

    var body: some View {               // what to draw; SwiftUI calls this whenever the input changes
        HStack {                        // lay the children out left to right
            VStack(alignment: .leading, spacing: 2) {   // name above date, left-aligned, 2 points apart
                Text(due.name)
                Text(due.dueDate.date, format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.secondary)        // modifiers: each one wraps the view and returns a new one
            }
            Spacer()                    // pushes the Amount to the right edge
            if let amount = due.amount {
                Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            } else {
                Text("No amount")
            }
        }
    }
}
```

At the bottom of `MonthView.swift`, `#Preview { ... }` is what Xcode's canvas shows; it is never part of the
running app.

Things to know when reviewing a view:

- A view describes what the screen looks like for its current input; it does not change the screen step
  by step. When the input changes, SwiftUI calls `body` again and updates what changed.
- `VStack` stacks vertically, `HStack` horizontally, `List` makes a scrolling table, `Section` groups rows.
- Modifiers read top to bottom, and their order matters: `.padding().background(.red)` colours the
  padding too, `.background(.red).padding()` does not.
- `@State` marks a value the view owns and can change (a text being typed); `@Binding` is a value owned by
  a parent that the view may change. `DueboardApp` owns the `Household` as `@State` and hands it down as a
  `@Binding`, so a Bill added in `BillFormView` shows at once in `BillsView`.
- The **canvas** (Editor > Canvas, or **Cmd-Option-Return**) renders the `#Preview` live next to the code.
- What to look for in review: a view should only show what the core returns and send commands to it. Any
  `if` that decides a domain rule (is this Due Overdue? can this Bill be added?) belongs in the core, with
  a test.

## How the core seam works

The household core is the one place every domain rule lives, and the one place tests run against. Screens
send it commands and show what it returns; they hold no rules of their own.

Its shape so far:

```swift
public struct Household {
    public static func open(in store: HouseholdStore, clock: WallClock) throws -> Household
    public var categories: [Category] { get }
    public mutating func addCategory(named name: String) throws -> Category
    public mutating func renameCategory(_ categoryID: Category.ID, to name: String) throws -> Category
    public mutating func reorderCategories(_ order: [Category.ID]) throws
    public mutating func deleteCategory(_ categoryID: Category.ID) throws
    public var billsList: BillsList { get }
    public mutating func addBill(_ new: NewBill) throws -> Bill
    public mutating func editBill(_ billID: Bill.ID, to details: NewBill) throws -> Bill
    public mutating func retireBill(_ billID: Bill.ID) throws -> Bill
    public mutating func reactivateBill(_ billID: Bill.ID) throws -> Bill
    public var currentBillingMonth: BillingMonth { get }
    public mutating func openBillingMonth(_ month: BillingMonth) throws -> MonthBoard
    public mutating func addDue(of billID: Bill.ID, to month: BillingMonth) throws -> Due
    public mutating func removeDue(_ dueID: Due.ID) throws
    public mutating func enterAmount(_ amount: Decimal?, on dueID: Due.ID, by member: String) throws -> Due
    public mutating func markPaid(_ dueID: Due.ID, paying paidAmount: Decimal? = nil, by member: String) throws -> Due
    public mutating func undoPaid(_ dueID: Due.ID) throws -> Due   // the Edit button
    public var reminderPlan: [Reminder] { get }
    public var remindedDues: Set<Due.ID> { get }
}
```

The `MonthBoard` that `openBillingMonth` returns also answers `state(of: due)`: Paid, Due Soon, Overdue,
or nil when nothing needs saying, and `takesPaidAmount(due)`: only a Due in the Credit Cards Category does. It
holds the month's Unpaid Remaining and its Unpaid Balance (nil when the cards hold nothing, so no warning
shows), and lists the Bills that can be added to the month by hand (`billsToAdd`). The state is derived as of the day the board was made, never stored, so
the Month board asks for a fresh board when the app comes back to the foreground.

A command that breaks a rule throws a refusal, such as `BillRefusal.dueDayOutOfRange`, whose
`localizedDescription` is the readable reason the screen shows ("Day must be 1 to 28").

**The store is injected.** `open(in:clock:)` loads the Household from a `HouseholdStore`, or starts a new
one with the suggested Categories when the store holds none. Every command writes what it changed to the
store. The app passes `CoreDataHouseholdStore`, which keeps everything in Core Data on the phone; tests and
previews pass `InMemoryHouseholdStore`. A store only keeps and returns records: the rules stay in
`Household`, so the tests of the core cover them whatever the store.

The Core Data model follows CloudKit's limits: every attribute optional or with a default, every
relationship optional and with an inverse, no unique constraints and no Deny delete rule.

**iCloud sync.** `CoreDataHouseholdStore` uses `NSPersistentCloudKitContainer`, which mirrors the store to
the member's private CloudKit database in the background. The core knows nothing of it. Signed out of
iCloud, or offline, the store works the same on the phone and syncs later. Three things the adapter adds:

- **Reading again.** The store's history records who made each change. When iCloud brings in one made on
  another device, the store says so, and `OpenedHousehold` in `DueboardApp.swift` opens the `Household`
  again from the store; the Month board and the reminder plan follow.
- **Merging duplicates.** With no server, two devices can each make the same thing before they see each
  other's change: a new device starts a Household with the suggested Categories before the one in iCloud
  arrives, or two devices open the same Billing Month offline, each with a Due per Bill. After every sync the
  store merges them: one Household, one Category per name, one Billing Month per month, one Due per Bill
  per month, keeping a Paid copy over one not Paid. Every device picks the same copy to keep
  (`Duplicates.swift`), so two devices tidying up at once never delete each other's. No delete rule
  cascades, so deleting a duplicate never takes records with it.
- **One store per CloudKit database.** The private store (`Dueboard.sqlite`, where it always was) mirrors
  the Member's private database and holds the Household started on this phone, shared or not. The shared
  store (`Dueboard-shared.sqlite`) mirrors the shared database and holds a Household the Member was invited
  to. Each new record is put in the store of the record it belongs to, and every command reads and changes
  records in the store of the Household shown only.

**Sharing.** The owner taps the people button at the top left of the Month tab. The first time, the store
shares the Household (`NSPersistentCloudKitContainer.share`), which moves it and everything hanging off it
into a CloudKit zone of its own, still in the owner's private database; then iCloud's own sharing screen
(`UICloudSharingController`) sends the invite by Messages, Mail or a link. Later taps show the same screen,
to see who joined, add someone or stop sharing; an invited Member sees it too, with Remove Me to leave.

- **Accepting.** `CKSharingSupported` in `Info.plist` has iOS open Dueboard when an invite is tapped. iOS
  hands the invite to `SceneDelegate` (`Sharing.swift`): in `scene(_:willConnectTo:options:)` when the tap
  launched the app, in `windowScene(_:userDidAcceptCloudKitShareWith:)` when it was running. Both pass it to
  `AcceptedInvites`, which keeps it until `OpenedHousehold` is ready. Accepting adds the owner's zone to the
  Member's shared database; the records arrive over the next moments, with a line along the bottom until
  they have, and then the Month tab shows the joined Household's current Billing Month.
- **Which Household shows.** A Member is in one Household at a time. A phone that holds a Household the
  Member was invited to (in the shared store) shows it; otherwise it shows the Member's own (in the private
  store). Accepting an invite does not delete the Member's own Household: it stays in their iCloud, hidden,
  and shows again after they leave or the owner stops sharing.
- **Stopping sharing and leaving.** Stop Sharing deletes the share; the owner's Household stays in their
  private database, and the store never purges anything there, which would delete it from the owner's iCloud.
  The Member's phone loses the zone on its next sync and iCloud takes the Household out of the shared store.
  A Member who taps Remove Me is taken off the share, and the store purges that zone from the shared store
  only (`purgeObjectsAndRecordsInZone`), so the Household goes at once. Either way the Household is read
  again, and Reminders for the Household that went are taken away, since its Dues are no longer in the plan.
- **Merging duplicates across stores.** Two Households in the private store are always copies of the
  Member's own and become one. Two in the shared store came with two invites, from two owners, and are never
  merged; only the copies within each Household are. Nothing is ever merged across the two stores.
- **Who marked Paid.** Once the Household is shared, the name recorded on a Due marked Paid is the Member's
  iCloud name, as the share knows it (`currentUserParticipant`). Before, or while iCloud has not said, it
  is the name typed on this phone.

Sharing is checked by hand on two devices with two iCloud accounts (`docs/manual-checklist.md`); the share's
record type, `cloudkit.share`, appears in the Development schema only after a first real share, so one is made
there before the schema is deployed to Production.

The CloudKit schema is made in the Development environment by running the app from Xcode, signed in to
iCloud, with the launch argument `-initializeCloudKitSchema` (Product > Scheme > Edit Scheme > Run >
Arguments), which creates every record type and field at once; saving records alone creates only the fields
they hold a value for. It is then deployed to Production in the CloudKit Console before a TestFlight build
syncs. After that a model change may only add
entities and optional attributes; nothing is renamed or removed.

A change to the Core Data model goes in a new model version, never into an existing one: Core Data upgrades
the store already on a phone only when the app still ships the model that store was made with. In Xcode,
select `Dueboard.xcdatamodeld`, then Editor > Add Model Version, make the change in the new version and set
it as current in the File inspector. `Dueboard 2` added Billing Month and Due; `Dueboard 3` added when and by
whom a Due was marked Paid; `Dueboard 4` added whether a Bill is Retired; `Dueboard 5` added whether a Bill
and its Dues are Card-Paid, and a Due's Paid Amount; `Dueboard 6` added an id to the Household and the Billing
Month, so devices merging duplicates pick the same one, and stopped deletes from cascading.

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

**Who marks Paid** is a name the core is handed, not one it looks up. Once the Household is shared, the app
hands it the Member's iCloud name; before, it asks for a name the first time a Due is marked Paid and keeps
it on the phone (`MonthView.swift`). `MembersTests` checks that a Due marked Paid by one Member shows as Paid,
with who and when, on another Member's Household opened from the same records.

**The reminder plan** is the list of notifications that should be pending now: for each Due that is not
Paid and whose Bill is not Retired, a `Reminder` at 8:00 in the clock's time zone on the day it becomes Due
Soon, on its Due Date and on the day after, less those already past, the 64 earliest in fire time order
(iOS keeps no more for an app). Each has an `id` made from its Due and kind, the same every time the plan is
made, a `fireDate`, a `title` and a `body`. The core never schedules anything: `ReminderNotifications` in the
app compares the plan with the phone's pending notifications, removes what is no longer planned or has
changed, and adds what is missing. It also clears the notifications already shown for a Due no longer among
`remindedDues`: the Dues not Paid whose Bill is not Retired, which the core answers too. `RootView` runs it
after launch, after every change to the plan or to `remindedDues`, including one synced from another device,
and on coming back to the app; that is how a Due marked Paid on the partner's phone stops reminding on this
one. With notifications declined it does nothing, and the app works the same.

**What comes next**: later tickets grow this same interface. Sharing the Household lives beside the
CloudKit adapter in the app, outside the core: the core never knows whether a Household is shared.

**`public`**: Swift hides everything in a module from other modules unless it is marked `public`. The
app and the tests are other modules, so in the core `public` marks the interface they may use, and anything
without it is an internal detail.
