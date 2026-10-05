# Bills Tracker

A monthly checklist of household bills so that every amount is paid before its due date. It records what is owed and whether it was paid; it does not do accounting, reconciliation, or budgeting.

## Language

**Household**:
The shared set of Categories, Bills and Billing Months.
_Avoid_: Account, family, workspace, team

**Bill**:
Something paid from a Billing Month, described once, e.g. "City Power". Defines the Category, the Due Day rule, and optionally a Default Amount. Either Recurring or Occasional. The Bills together are the one list every Due is drawn from.
_Avoid_: Expense, template item, subscription, catalog, inventory

**Recurring**:
A Bill that gets a Due generated for it in every Billing Month opened from now on. The default for a new Bill, and what every Bill was before Occasional existed.
_Avoid_: Template, default set, automatic

**Occasional**:
A Bill that never gets a Due generated on its own; it is added to a Billing Month by hand, in the months it is paid.
_Avoid_: One-off, ad hoc, optional

**Due**:
One Bill in one Billing Month: a fixed Due Date, an optional Amount, and whether it is Paid. Generated from the Bill, either when the month is first opened (Recurring Bills) or when the Bill is added to the month by hand, and then independent of it. At most one per Bill per Billing Month. A Due that is not Paid can be removed from its month, which deletes it; adding the Bill again generates a fresh Due.
_Avoid_: Expense, payment, line item, instance

**Billing Month**:
The calendar month in which a Due must be paid, and the set of Dues paid from it. A Due belongs to the month it is paid from, even when its Due Date falls in the following month (Riverside School paid in August is due September 1). Opened with a Due for each Recurring Bill; after that, Dues are added and removed by hand, and changing a Bill between Recurring and Occasional never touches a month already opened.
_Avoid_: Period, cycle, template

**Category**:
A named group of Bills. Each Household has its own Categories, in its own order, and creates, renames, reorders and deletes them; a new Household starts with House, Education and Credit Cards as suggestions. Names are unique within a Household, whatever the case. A Category is deleted only when it holds no Bill, Retired ones included, and no Due: a Due stays in the Category it was generated in when its Bill moves to another. The Bills in the Credit Cards Category are the Credit Card Bills; it is the Category named Credit Cards, whatever the case, so it cannot be renamed to anything else.
_Avoid_: Group, section, bucket

**Due Day**:
A specific day number on which a Bill is due, tagged as falling in the Billing Month itself (Same Month) or the month after (Next Month). Every Bill has one. Always the nominal day; no weekend or holiday shifting.
_Avoid_: Deadline, cutoff

**Due Date**:
The concrete calendar date a Due must be paid by, computed from the Bill's Due Day and the Billing Month.

**Default Amount**:
An amount a Bill pre-fills into each new Due when the real amount is constant or predictable (Mortgage, Riverside School, Dance Studio). Editing a Due's Amount never changes the Bill's Default Amount.
_Avoid_: Fixed amount, estimate

**Amount**:
The money owed on a Due. Unknown until entered, except when pre-filled from a Default Amount. Plain number, single currency.

**Paid**:
The state of a Due once it has been dealt with for its Billing Month: its Amount paid in full or, for a credit card Due, its Paid Amount paid and the rest left as Unpaid Balance. Records when and by whom. A Due whose Amount is zero is Paid from birth. The Amount cannot be edited while the Due is Paid; Edit (undo Paid) first, then change it. The button that undoes Paid is labelled Edit.
_Avoid_: Settled, cleared, done, partially paid

**Credit Card Bill**:
A Bill in the Credit Cards Category; being in that Category is what makes a Bill a credit card, never a setting of its own. Its Dues are credit card Dues: they take a Paid Amount and can leave an Unpaid Balance.
_Avoid_: Card account, Credit Cards Due

**Paid Amount**:
What was actually paid on a credit card Due when it is less than its Amount. Entered before marking the Due Paid; empty means the whole Amount. One per Due, changed only by undoing Paid and marking it Paid again. Only credit card Dues have one; every other Due is paid in full or not at all.
_Avoid_: Partial payment, instalment, minimum payment

**Unpaid Balance**:
Amount minus Paid Amount on a Paid credit card Due: what the card still holds. Belongs to the Billing Month it was left in and is never moved to the next one, because the card's next statement already includes it. Summed across the credit card Dues of a Billing Month and shown as a warning under Unpaid Remaining, only when it is more than zero.
_Avoid_: Carried over, rollover, balance forward, remainder

**Retired**:
A Bill that is no longer paid at all: it gets no Dues generated and cannot be added to a Billing Month by hand. Its past Dues remain; it can be reactivated.
_Avoid_: Deleted, archived, inactive, closed

**Overdue**:
A Due that is not Paid and whose Due Date has passed. Derived, never set by hand.
_Avoid_: Late, missed

**Due Soon**:
A Due that is not Paid and whose Due Date is today or within the next 7 days. Derived, never set by hand.
_Avoid_: Upcoming, pending, imminent

**Reminder**:
A notification planned from a Due's state, at 9:00 local time on the day the Due becomes Due Soon, on its Due Date and on the day after. Only for Dues that are not Paid and whose Bill is not Retired; marking the Due Paid, by anyone in the Household, takes its Reminders away, and Edit brings them back. The phone keeps at most the 64 earliest.
_Avoid_: Alert, alarm, nudge, push

**Unpaid Remaining**:
The one number shown per Billing Month: the sum of Amounts on Dues that are not Paid, excluding Card-Paid Bills. Reaches zero when every Due is Paid, whatever Unpaid Balance the cards still hold.
_Avoid_: Total, balance, outstanding

**Direct Bill**:
A Bill paid from the bank account. The normal case.

**Card-Paid Bill**:
A Bill settled by charging a credit card (Dance Studio, State University). Tracked only as a reminder, since the money also appears in that card's Due. Each Due is Card-Paid as its Bill was when the Due was generated: clearing Card-Paid leaves the existing Dues Card-Paid and the later ones not.
_Avoid_: Memo, informational, pass-through