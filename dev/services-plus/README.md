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

## Setup

1. Import [`sql/install.sql`](sql/install.sql) (`CREATE TABLE IF NOT EXISTS` /
   `ADD COLUMN IF NOT EXISTS` throughout, so re-running it after an update is
   always safe - needs MySQL 8.0.29+ / MariaDB 10.0.2+ for the phase 3
   migration block at the bottom).
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
