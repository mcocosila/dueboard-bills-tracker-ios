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

## Sharing the Household

Two devices signed in to **different** iCloud accounts, both adults (an account under 13 may not be allowed
to join a share), both on the same kind of build as for iCloud sync. Device A is the owner's, with a
Household that has a few Bills; device B is the Member's, with Dueboard installed. Invites are sent by
Messages or Mail between the two accounts. The Simulator does not open invites reliably: use real devices.

### Invite

1. On A, Month tab, tap the people button at the top left. iCloud's sharing screen opens titled "Dueboard
   household". Check that Permission is Can make changes and Only invited people can access.
2. Send the invite to B's account by Messages (or Mail). The screen closes without an error.
3. Tap the people button again: the same screen shows B's account as invited, not a second invite.

### Accept

1. On B, with Dueboard **not running** (swipe it away), tap the invite in Messages and Open. Dueboard opens,
   with "Joining the household" along the bottom.
2. Within a minute the line goes and the Month tab shows A's Household on its current Billing Month: A's
   Bills, Categories and Dues, not B's own.
3. On A, the people button's screen now shows B as accepted.

The Leave steps below check accepting while Dueboard is already running.

### Paid syncs with who and when

1. On B, enter a Due's Amount and mark it Paid. The row reads "Paid <date> by <B's iCloud name>", with no
   question asking for a name.
2. On A, without restarting, the Due turns Paid within a minute with B's iCloud name and the date, and Unpaid
   Remaining drops.
3. On A, Edit the Due and mark it Paid again: on B it reads Paid by A's iCloud name.
4. On B, add a Bill and a Category; on A, rename a Category. Both devices show all three.

### Stop sharing

1. On A, tap the people button, then Stop Sharing, and confirm.
2. On A, the Household is still there, unchanged, with every Bill and Due.
3. On B, open Dueboard (bring it to the foreground). Within a minute A's Household is gone: B shows its
   own Household again (or a new one with the suggested Categories), and no Reminder from A's Dues fires on B.

### Leave

1. Invite B again. On B, with Dueboard open in the background this time, tap the invite: the Household is
   joined as above.
2. On B, tap the people button (it reads Household members), then Remove Me, and confirm.
3. On B, A's Household goes at once and B's own shows again.
4. On A, the Household is still there and the people button's screen no longer lists B.

### Signed out of iCloud

1. On a device signed out of iCloud, the people button is greyed out, and the line along the bottom reads
   "Saved on this device only: sync and sharing need iCloud."

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
