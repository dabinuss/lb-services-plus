# Services+

Extended companies/services app for LB Phone. See [`SERVICES+ PLAN.md`](../../SERVICES+%20PLAN.md)
at the repo root for the full spec. Phases 1-3 are implemented - this is a
feature-complete Services+ 1.0 per the plan.

## What exists so far

**Phase 1** - resource skeleton, registered as an LB-Phone custom app
dynamically via `AddCustomApp` (no files copied into `lb-phone`, no core
edits); ESX/QBCore/Qbox/standalone framework adapter; company/category data
model; Services overview with search/category filter/availability; multi-
number messaging with its own React UI; personal Activity tab; fake-login.

**Phase 2** - company dashboard (duty/status/hotlines/team/messages/
calls/settings), the request system (types, atomic first-accept-wins,
competition requests, GTA waypoint), call routing that resolves a target and
then places a fully native `createCall`, in-memory employee runtime state.
See `ui/src/screens/company/`, `server/requests.lua`, `server/calls.lua`,
`server/employees.lua`.

**Phase 3** - added on top:

- **Sibling-NUI request notifications** (`ui/overlay/`, `client/overlay.lua`,
  SIBLING-NUI.md technique): a second, tiny NUI page injects a request card
  directly into the CitizenFX root document - not into lb-phone's own
  iframe, so it works even with the phone closed or at peek (plan §44).
  Accept/Decline, then an active card with a live distance readout and
  Complete/Cancel. Max one on screen at a time; extras queue. Accepting
  anywhere (overlay or the in-app Requests tab) tells every other notified
  employee to drop theirs (`server/requests.lua`'s `notifiedSources`/
  `clearNotifications`).
- **Admin area** (`ui/src/screens/admin/`, `server/admin.lua`): full CRUD for
  companies (incl. numbers and boss assignment by online player ID),
  categories, and request types; per-company admin ceilings for calls/
  messages/requests that a boss's own settings can never exceed (plan §34,
  §53) - see the `admin_*_allowed` columns and `admin:setCompanyCeiling`.
  Competition now requires **both** the category and the request type to
  allow it (plan §16).
- **Framework.SetJob** (`server/framework.lua`): backs boss assignment across
  ESX/QBCore/Qbox/standalone.

Everything in the plan is implemented except: Skill/priority routing,
round-robin, and other systems the plan explicitly excludes (§71) - those
were never in scope.

**Post-review hardening pass** (600+ player scale + security):

- `server/framework.lua`'s `JobIndex`: `Framework.GetPlayersByJob()` used to
  scan every online player on every availability/eligibility check. It's now
  a maintained `job -> sources` index (framework job/duty events + a
  self-healing side effect of `Framework.GetJob()`), so a 600-player server
  costs a lookup over the handful of actual employees, not a full scan.
- Server-side rate limiting (`server/callback.lua`): a token bucket per
  player, global plus tighter per-action limits for `sendMessage`,
  `createRequest`, `resolveCall`, admin writes, etc. - the NUI callback
  NetEvent previously trusted whatever action name a client sent, with no
  limit at all.
- Fixed an authorization gap in `archiveConversation` (no employment check -
  any client with a guessed `channelId` could mark a company chat archived)
  and in `resolveCall` (a DB row was written before any real call happened,
  letting a modified client spam the call history table).
- `notifiedSources` cleanup and the pending-call sweep no longer run a
  database query per tracked item in a loop - both are pure in-memory TTL
  sweeps now, backed by a single batched `UPDATE` instead.
- Added the composite indexes messages/channels/calls/requests actually
  query by, a `UNIQUE(number_id, contact_number)` constraint (closes a
  double-channel race), company `messages_enabled`/`enabled` enforcement,
  a re-check of duty/status/hotline in `acceptRequest` (not just job/
  category), a client-side callback timeout, and no longer forwarding raw
  server error text to the client.
- Fixed `Standalone.GetJob` reading `company.bossGrade` (always nil) instead
  of `company.boss_grade` - a standalone-assigned boss was never recognized
  as one. `Framework.IsBoss` (using the company's configurable `boss_grade`)
  is now used everywhere instead of the framework-native `job.isBoss`
  heuristic, including for ESX/QB/QBX.
- New messages now push into an already-open conversation via
  `SendCustomAppMessage` instead of only updating on next reopen.

**Second hardening pass** (deeper look at calls, the overlay, and a couple
of smaller correctness/perf items):

- Call history could previously be attributed to the wrong call: `resolveCall`
  only tracked the customer's number, so dialing something else entirely
  within the 20s pending window could get logged as the resolved request.
  The pending state now also records the exact expected target
  (`company`/number) and `lb-phone:newCall` only consumes it on a real match.
- Call `answered`/`ended` tracking no longer depends on an in-memory
  `callId -> row` map that a Services+ restart mid-call would lose (leaving
  an actually-answered call to time out as "missed" an hour later). A new
  `lb_call_id` column correlates directly in the database instead - restart-safe.
- "All" call routing for a company's main number rings through lb-phone's
  own native company-call system, which has no idea about Services+'s own
  Busy/Pause/off-duty state. `client/main.lua` now keeps lb-phone's
  (global, per-player) `ToggleCompanyCalls` in sync with it - a deliberate,
  documented trade-off given lb-phone exposes no finer-grained hook.
- Accepting a request from the in-app Requests tab used to leave the
  Sibling-NUI overlay's own pending/active state out of sync (and could
  leave a stale pending card on the accepting player's own screen). The
  server now sends a targeted `requestAccepted` event to the winner after
  any successful accept, and the overlay's active-card state always comes
  from that event regardless of which UI triggered the accept.
- `Employees.GetEligible`/`GetTeam` had a leftover O(employees²) path for
  hotline/duty-count checks on a big job (each employee re-scanning the
  whole job's duty count). Computed once per call now, not once per employee.
- `createRequest`'s passenger count is now bounded (whole number,
  `1..Config.MaxPassengerCount`) instead of accepting whatever `tonumber()`
  parsed.
- `Employees` runtime state is now keyed by `source` instead of the
  framework identifier - re-deriving an identifier on `playerDropped` risked
  the framework returning a different fallback than the state was stored
  under.
- `MAX_PAGE` lowered from 10000 to 200 (still generous, no longer allows a
  quarter-million-row OFFSET), and fixed an off-by-one in `isAdminWrite()`
  that was rate-limiting every `admin:get*` read as if it were a write.

## Setup

1. Import [`sql/install.sql`](sql/install.sql) (`CREATE TABLE IF NOT EXISTS` /
   `ADD COLUMN IF NOT EXISTS` throughout, so re-running it after an update is
   always safe - needs MySQL 8.0.29+ / MariaDB 10.0.2+ for the phase 3
   migration block at the bottom, and MariaDB for the post-review hardening
   block's `ADD INDEX IF NOT EXISTS`/`ADD UNIQUE KEY IF NOT EXISTS` - on
   plain MySQL, drop the `IF NOT EXISTS` there and run it once).
2. `cd ui && npm install && npm run build`.
3. Make sure `resources/services-plus` on your dev server is a **junction**
   pointing at this `dev/services-plus` folder, not a copy - see the repo
   root's dev-server setup. (Already set up locally: `E:\FiveMServer\txData\
   FiveMBasicServerCFXDefault_71E096.base\resources\services-plus` → this
   folder.)
4. `ensure lb-phone` before `ensure services-plus` (declared as an fxmanifest
   dependency too).
5. Grant yourself the `servicesplus.admin` ACE permission (or add your
   license identifier to `Config.AdminIdentifiers` in `shared/config.lua`) to
   see the Admin tab, and use it to create your first company + main number -
   `Config.DefaultCompanies` in `shared/categories.lua` is empty by default.

`Config.Framework` defaults to `"auto"` - set it explicitly if detection ever
picks the wrong framework.

## UI dev loop

See [`ui/README.md`](ui/README.md). `npm run dev` (port 5173, matches
`.claude/launch.json`) works standalone in a browser with fixture data (see
`ui/src/lib/nui.js`) - **except** `ui/overlay/`, which has no build step and
can't be meaningfully previewed outside an actual lb-phone client (there's no
root NUI document to inject into in a plain browser tab). Run `npm run build`
before testing in-game since the resource serves `ui/dist`.
