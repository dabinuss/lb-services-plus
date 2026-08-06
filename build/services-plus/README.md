# Services+

Services+ is a separate LB Phone custom app resource providing a company directory, native multi-number calls, shared inboxes with LB Phone media and reactions, structured requests, and a server-authoritative employee portal. The portal keeps requests, inboxes, calls and the searchable active team in separate paginated workspace tabs. Red tab counters are reserved for unanswered requests, unread messages and calls not yet viewed during the current app session; neutral counters show zero or informational team totals.

Version `0.7.0-rc1` adds API v11 payload hardening (undeclared fields and oversized payloads are rejected), server-resolved message locations, request/message idempotency keys, authorization fixes for ending company calls and reoffering failed call acceptances, and soft-deleted companies/numbers that keep history readable. Production promotion still requires the live-server evidence in the release checklist.

## Documentation

- [Documentation index](docs/INDEX.md): all technical documentation
- [Installation](docs/guides/INSTALLATION.md): deployment and upgrades
- [Configuration](docs/guides/CONFIGURATION.md): settings and permissions
- [Compatibility](docs/reference/COMPATIBILITY.md): supported boundaries and validation matrix
- [Database operations](docs/guides/DATABASE.md): migrations, backups and rollback
- [Troubleshooting](docs/guides/TROUBLESHOOTING.md): operational diagnosis
- [Integrations](docs/reference/INTEGRATIONS.md): optional-resource boundaries
- [API reference](docs/api/API.md): complete exports, events, callbacks, entities and examples
- [Generated contract inventory](docs/api/CONTRACT_INVENTORY.md): action, payload, export, event and push metadata generated from the runtime contract source
- [Release checklist](docs/development/RELEASE_CHECKLIST.md): automated and live release gates
- [Changelog](docs/CHANGELOG.md): versioned changes

## Requirements

- Current LB Phone release
- `oxmysql`
- ESX, QBCore, Qbox, or configured standalone mode
- OneSync-enabled FiveM server

## Installation

The authoritative deployment procedure is in [the installation guide](docs/guides/INSTALLATION.md).

1. Back up the server database.
2. Apply `sql/install.sql` to the server database.
3. Configure the framework and companies in `config.lua`.
4. Build the UI with `npm install` and `npm run build` in `ui/` when the shipped `web/` output is unavailable.
5. Add resources in this order:

```cfg
ensure oxmysql
ensure lb-phone
ensure services-plus
```

The resource checks required dependencies and the schema version during startup. It does not modify LB Phone or framework files.

## Configuration

See [the configuration guide](docs/guides/CONFIGURATION.md) for the complete configuration reference.

`Config.Framework` accepts `auto`, `esx`, `qbcore`, `qbox`, or `standalone`. Automatic detection prioritizes Qbox, QBCore, then ESX. Standalone player mappings are keyed by the FiveM license identifier.

Companies configured in `Config.Companies` are used only to seed an empty company table. After the first seed, company records are managed through the protected admin UI, so deleted companies do not reappear after a restart. Company jobs must be unique. Leader access is derived from `Config.LeaderGrades`, `Config.ExplicitLeaders`, or persisted explicit leader assignments.

Server administration is granted through the `servicesplus.admin` ACE or a supported ESX/QBCore administrator role. Recommended ACE configuration:

```cfg
add_ace group.admin servicesplus.admin allow
```

Server administrators can create, edit and delete companies, configure logos, card backgrounds, all company numbers, global call/request availability, and request competition independently for every category. Each number has separate enabled, call, inbox, request and public-visibility controls. When category competition is enabled, available employees from every company in that category receive the offer and atomically compete for assignment. Company leaders can change operational toggles, number distribution, enabled request templates, request labels, fields, required fields and navigation behavior. Category workflow steps are fixed and cannot be removed or reordered by company leaders. Active team contact actions resolve phone numbers server-side and use LB Phone's documented call/contact APIs.

There is no administrative line-staffing mode or employee allow-list. Activating dispatch initially selects every enabled company number; the dispatcher can then deselect or reselect individual numbers for the current duty session. Numbers using the `dispatch_only` distribution are offered only to active dispatchers who selected that number. Normal `ring_all` and `random` numbers remain available to on-duty employees. Only active call numbers are registered through LB Phone on an employee's client. Every enabled shared inbox is displayed as an explicit number tab even before a conversation exists and remains available independently of dispatch line selection. Disabled inboxes reject citizen messages server-side.

The per-number citizen-directory option controls whether enabled calls, messages and requests are offered to citizens. It does not hide an enabled internal inbox from on-duty company employees.

On-duty employees can select Available, On Break, or the red Busy status. The manual Busy status is stored internally as `occupied` and suppresses call/request offers and their notifications; it does not block shared-inbox messages. The internal `busy` status remains reserved for an accepted active call or request and cannot be selected manually. The active team is ordered by leader status and the server-resolved numeric framework job grade before status and name.

Duty is tied to the connected player session and the equipped LB Phone number. Closing Services+, switching apps, or closing the phone does not end duty. Explicit logout, disconnect, employment changes, removing the phone, or equipping another phone invalidates duty. A server-side player state restores duty after a Services+ resource restart only when identity, employment and equipped number still match.

Employees currently marked as dispatch may soft-delete requests belonging to their own company, authorized shared-inbox conversations, and individual messages. These actions are audited in Services+ metadata and only remove the entries from Services+ workflows; native LB Phone message records are not modified. Call history is immutable and has no delete API or control.

Available employees receive incoming requests as interactive LB Phone notifications. Requests can be declined with `-` or accepted with `+` directly from the notification without opening Services+ first; the in-app incoming request view provides the same controls.

When the phone is usable and no native call is active, an incoming request brings the phone and Services+ offer screen on screen. The default request keybinds mirror LB Phone calls: `ENTER` accepts and `BACKSPACE` declines. They are separate FiveM key mappings so players can change them in GTA settings without modifying LB Phone.

Category request definitions are data-driven in `shared/request_definitions.lua`. Requests are reserved for category-specific structured workflows: pickup, roadside/towing assistance, delivery, table reservations, medical transport, property viewing, legal assistance and police requests. General questions, appointments, complaints, information and callbacks use company messages instead. Categories without a specialized definition expose no citizen request action and cannot enable requests in the admin or leader UI. Select options are allow-listed and validated server-side. Phone fields are prefilled from the currently equipped LB Phone number but remain ordinary editable text fields. Taxi pickup requests capture the citizen's GTA coordinates server-side and do not ask for a textual location. Add a field definition, template, category mapping, and fixed phase set to introduce another controlled workflow without changing request rendering. Company-specific choices remain stored in `services_plus_company_request_settings`; obsolete or unknown templates and fields are rejected or safely replaced with valid defaults.

If request options cannot be loaded or a request cannot be created, the request composer stays open and tells the citizen in the selected language to call the company instead. Internal server errors are not exposed in the player-facing message.

Citizens receive live in-app updates and LB Phone notifications when their request is accepted, returned, moved to another phase, completed, cancelled or deleted. Active requests are shown separately from request history. Request navigation can be disabled, offered as a notification action, or set automatically for the successful assignee; coordinates are derived server-side through OneSync and sent only after assignment.

Trusted MDT, dispatch and business resources can use the allow-listed server exports documented in the [API reference](docs/api/API.md). Add resource names to `Config.ApiAllowedResources`. Do not invoke Services+ internal network events from another resource.

The company request list shows the name and role snapshot of the employee who accepted each active or completed request. Trusted integrations receive the same primary assignee with a stable identifier and optional active player source. Services+ intentionally does not model patrol units, multiple officers or live tracking; external dispatch and MDT resources correlate those records through the request ID and the documented `requestLifecycle` event.

Set `Config.RequireEquippedPhone = false` only for development environments where LB Phone has no equipped-phone concept available.

Optional integrations are disabled by default. See [integration boundaries](docs/reference/INTEGRATIONS.md) before adding an adapter.

## Database Changes

See [database operations](docs/guides/DATABASE.md) before changing an existing installation.

Schema changes are versioned in `sql/migrations/`. Before applying any production migration:

1. Stop `services-plus`.
2. Create a database backup.
3. Apply the migration in version order.
4. Start `services-plus` and verify the reported schema version.

Rollback requires restoring the pre-migration backup. Do not drop Services+ tables on a production database without a verified backup.

Existing installations must apply migrations through `sql/migrations/012_call_duration_and_distribution.sql` before restarting the resource. Migration 004 adds call queues, per-number conversations/messages/read state, and Phase 2 request lifecycle columns. Migration 005 adds persistent per-user message reactions. Migration 006 adds audited soft deletion for requests, shared-inbox conversations and individual messages. Migration 007 adds granular number operations, request target numbers, navigation coordinates and idempotent external references. Migration 008 removes obsolete staffing modes, employee allow-lists and persistent line subscriptions. Migration 009 adds persistent assignee name and role snapshots for portal and integration responses. Migration 010 adds the filtered activity index used by stable inbox pagination. Migration 011 adds soft deletion (`deleted_at`/`deleted_by`) for companies and company numbers so history stays readable after deletion. Migration 012 adds the number distribution mode captured at call time; queue and call duration are derived from existing timestamps. Active requests are safely returned and active calls are ended after a resource restart.

## Development Checks

Run from `ui/`:

```sh
npm run typecheck
npm run lint
npm test
npm run test:contracts
npm run build
```

The frontend can be opened through the Vite development server. Browser mode provides isolated mock data for directory, duty, request, activity and administration UI testing.
