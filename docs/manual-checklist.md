# Manual checklist

What the household core's tests cannot cover: the adapters that talk to the phone. Every TestFlight build is
checked against this list on two phones, and issue 14 gathers the steps of the other tickets into it.

## Reminders

Set up on phone A, with notifications not yet allowed for Dueboard:

1. Add a Bill due 8 days from today and open the Month board. A dialog explains the Reminders; Continue
   brings the phone's own question. Allow it.
2. Settings > Notifications > Dueboard is on.

### A Reminder fires

1. In Settings > General > Date & Time, turn off Set Automatically and set the date to tomorrow and the time
   to 8:58, when the Bill is 7 days away.
2. Wait for 9:00 with the phone locked. A notification arrives titled with the Bill's name: "Due Soon: due in 7
   days."
3. Tap it. Dueboard opens on the Month tab, on the Due's Billing Month, even from the Bills tab.
4. Turn Set Automatically back on.

### A Reminder disappears after the partner marks Paid

Needs iCloud sync (issue 11) and a shared Household (issue 12).

1. On phone A, with a Due not Paid that is Due Soon, open Dueboard so its Reminders are pending.
2. On phone B, mark that Due Paid.
3. On phone A, open Dueboard and wait for the change to arrive. Move the clock to 8:58 on its Due Date as above:
   no notification arrives at 9:00.
4. On phone B, Edit the Due back to not Paid. On phone A, after the change arrives, the Reminder is back: it
   fires at 9:00 on the Due Date.

### Declined

1. Delete and reinstall Dueboard, add a Bill and choose Don't Allow when the phone asks.
2. Add, pay, Edit and remove Dues: everything works, and no notification ever arrives.
