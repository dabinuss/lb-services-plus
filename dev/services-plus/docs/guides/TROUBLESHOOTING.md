# Troubleshooting

## Resource Does Not Initialize

Confirm `oxmysql` and `lb-phone` are started first. Read the first Services+ console error; framework and schema failures intentionally keep the API unavailable. Verify `Config.Framework` matches the running resource name and all migrations through 009 are present.

## App Is Missing or Blank

Confirm `web/index.html` and `web/assets/` were deployed from a successful production build. Restart `services-plus` after LB Phone is fully started. Check LB Phone custom-app support and enable `Config.Debug` only while collecting diagnostics.

## Company Appears Offline

At least one eligible employee must be on duty and available for the relevant enabled number. Check the company job mapping, number master switch, channel switch, citizen visibility, employee status, equipped phone, and dispatch-only line selection.

## Number or Company Changes Disappear

Confirm the administration save request succeeds and inspect database errors. Configured companies seed only an empty database; persistent edits are stored in Services+ tables. Browser preview data is temporary and never represents database persistence.

## Calls, Requests, or Messages Do Not Arrive

Check the global switch, company switch, target-number channel switch, employee duty/status, and number distribution. Busy and on-break employees do not receive work offers. Disabled inboxes reject messages. Inspect rate-limit and permission warnings before increasing limits.

## UI Remains Loading

The release candidate converts NUI timeout and rejection paths into retryable UI states. If this repeats, inspect client and server logs for `services-plus:server:request`, dependency state, callback timeout, and database latency. Do not hide the issue by using an unlimited timeout.

## Optional Integration Is Missing

Disable the adapter or correct its resource name. Optional adapters must degrade gracefully and may not be required for core startup. Never patch the third-party resource to make Services+ load.

## Support Data

Provide the Services+ version, LB Phone/framework/database versions, startup order, relevant console lines, exact workflow, and whether the issue reproduces after a clean resource restart. Remove player identifiers, phone numbers, and message contents from public reports.
