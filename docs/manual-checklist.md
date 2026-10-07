# Manual checklist

What the household core's tests cannot cover: the adapters that talk to the phone. Every TestFlight build is
checked against this list on two phones, and issue 14 gathers the steps of the other tickets into it.

## iCloud sync

Two devices signed in to the **same** iCloud account, both with iCloud Drive on and Dueboard allowed under
Settings > [your name] > iCloud > Apps Using iCloud. A build run from Xcode syncs through CloudKit's
Development environment, a TestFlight build through Production, and the two never see each other's data: check
both devices on the same kind of build. The first sync after installing can take a minute; bringing the app to
the foreground or waiting nudges it along.

### A change on one device appears on the other

1. On device A, with Dueboard set up, add a Bill and open the current Billing Month.
2. Install Dueboard on device B and open it. Within a minute, B shows A's Bill and the month's Due, with
   one set of Categories (House, Education, Credit Cards), not two.
3. On B, enter the Due's Amount and mark it Paid. On A, without restarting the app, the Due turns Paid with
   B's name and the time, and Unpaid Remaining drops.
4. On A, Edit the Due back to not Paid, rename a Category and add a Bill. B shows all three.

### Changes made offline sync when the connection returns

1. On device A, turn on Airplane Mode. Mark a Due Paid and add a Bill: both work as usual.
2. On device B, the change does not show.
3. On A, turn Airplane Mode off and open Dueboard. Within a minute, B shows the Due Paid and the new Bill.

### The same Billing Month opened on two devices at once

1. Pick a Billing Month neither device has shown yet, usually the month after the current one: stay on the
   current month on both.
2. Turn on Airplane Mode on both. On each, step to the next month: each opens it with its own Dues. Mark one
   Due Paid on device A only.
3. Turn Airplane Mode off on both and wait for sync. Each device shows the month with one Due per Bill, the
   one marked Paid on A still Paid, and the same on both.

### Signed out of iCloud

1. On a device signed out of iCloud (Settings > [your name] > Sign Out, or a Simulator never signed in),
   open Dueboard. A line along the bottom of both tabs reads "Saved on this device only: sync and sharing
   need iCloud."
2. Add a Bill, mark a Due Paid, quit and reopen: everything is still there.
3. Sign in to iCloud and come back to Dueboard: the line goes away, and what was saved while signed out
   syncs to the other devices on that account.

## Reminders

Set up on phone A, with notifications not yet allowed for Dueboard:

1. Add a Bill due 8 days from today and open the Month board. A dialog explains the Reminders; Continue
   brings the phone's own question. Allow it.
2. Settings > Notifications > Dueboard is on.

### A Reminder fires

1. In Settings > General > Date & Time, turn off Set Automatically and set the date to tomorrow and the time
   to 7:58, when the Bill is 7 days away.
2. Wait for 8:00 with the phone locked. A notification arrives titled with the Bill's name: "Due Soon: due in 7
   days."
3. Tap it. Dueboard opens on the Month tab, on the Due's Billing Month, even from the Bills tab.
4. Turn Set Automatically back on.

### A Reminder already shown is cleared once its Due is Paid

1. Let a Reminder fire as above and leave it in Notification Center, without tapping it.
2. Open Dueboard from its icon and mark that Due Paid.
3. Notification Center no longer shows the Reminder.

### A Reminder disappears after the partner marks Paid

Needs iCloud sync (issue 11) and a shared Household (issue 12).

1. On phone A, with a Due not Paid that is Due Soon, open Dueboard so its Reminders are pending.
2. On phone B, mark that Due Paid.
3. On phone A, open Dueboard and wait for the change to arrive. Move the clock to 7:58 on its Due Date as above:
   no notification arrives at 8:00.
4. On phone B, Edit the Due back to not Paid. On phone A, after the change arrives, the Reminder is back: it
   fires at 8:00 on the Due Date.

### Declined

1. Delete and reinstall Dueboard, add a Bill and choose Don't Allow when the phone asks.
2. Add, pay, Edit and remove Dues: everything works, and no notification ever arrives.
