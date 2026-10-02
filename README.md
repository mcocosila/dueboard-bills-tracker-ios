# Dueboard: Bills Tracker

An iPhone app: a shared monthly checklist so every household bill is paid before its due date. Data lives on
the phone and syncs through iCloud; a household is shared with an iCloud invite. Vocabulary is in
[CONTEXT.md](CONTEXT.md).

It replaces the Django web app in the private repo `mcocosila/pay-bills-tracker`, which is
retired once this app has run a full Billing Month on TestFlight.
Its pytest suite is the reference for the household core's tests: every domain test there gets a Swift
counterpart. Read it with `gh repo clone mcocosila/pay-bills-tracker` (needs access to the private repo).
