# Services+ Phase 2

Services+ is a separate LB Phone custom app resource providing a company directory, native multi-number calls, shared inboxes with LB Phone media and reactions, structured requests, and a server-authoritative employee portal.

## Requirements

- Current LB Phone release
- `oxmysql`
- ESX, QBCore, Qbox, or configured standalone mode
- OneSync-enabled FiveM server

## Installation

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

`Config.Framework` accepts `auto`, `esx`, `qbcore`, `qbox`, or `standalone`. Automatic detection prioritizes Qbox, QBCore, then ESX. Standalone player mappings are keyed by the FiveM license identifier.

Companies configured in `Config.Companies` are used only to seed an empty company table. After the first seed, company records are managed through the protected admin UI, so deleted companies do not reappear after a restart. Company jobs must be unique. Leader access is derived from `Config.LeaderGrades`, `Config.ExplicitLeaders`, or persisted explicit leader assignments.

Server administration is granted through the `servicesplus.admin` ACE or a supported ESX/QBCore administrator role. Recommended ACE configuration:

```cfg
add_ace group.admin servicesplus.admin allow
```

Server administrators can create, edit and delete companies, configure logos, card backgrounds, all company numbers, global call/request availability, and request competition independently for every category. Each number has separate enabled, call, inbox, request and public-visibility controls. When category competition is enabled, available employees from every company in that category receive the offer and atomically compete for assignment. Company leaders can change operational toggles, distribution and staffing modes, per-number employee eligibility, enabled request templates, request labels, fields, required fields, workflow phases and navigation behavior. Active team contact actions resolve phone numbers server-side and use LB Phone's documented call/contact APIs.

Number authorization and line staffing are separate. `all` automatically staffs every authorized employee, `self_select` allows employees to select their active lines, `restricted` combines leader-managed authorization with employee selection, and `dispatch_only` follows active dispatch state. Activating dispatch initially staffs every authorized active line; the dispatcher can then deselect individual lines for the current duty session. Only active staffed call numbers are registered through LB Phone on that employee's client. Every enabled authorized shared inbox is displayed as an explicit number tab even before a conversation exists and remains available when its call line is not staffed. Disabled inboxes reject citizen messages server-side.

For `restricted` staffing, server administrators select eligible currently on-duty employees in the company editor and company leaders can manage the same list in the company portal under Restricted line access; an empty eligibility list denies the line to everyone. The per-number citizen-directory option controls whether enabled calls, messages and requests are offered to citizens. It does not hide an enabled internal inbox from authorized employees.

On-duty employees can select Available, On Break, or the red Busy status. The manual Busy status is stored internally as `occupied` and suppresses call/request offers and their notifications; it does not block shared-inbox messages. The internal `busy` status remains reserved for an accepted active call or request and cannot be selected manually.

Duty is tied to the connected player session and the equipped LB Phone number. Closing Services+, switching apps, or closing the phone does not end duty. Explicit logout, disconnect, employment changes, removing the phone, or equipping another phone invalidates duty. A server-side player state restores duty after a Services+ resource restart only when identity, employment and equipped number still match.

Employees currently marked as dispatch may soft-delete requests belonging to their own company, authorized shared-inbox conversations, and individual messages. These actions are audited in Services+ metadata and only remove the entries from Services+ workflows; native LB Phone message records are not modified. Call history is immutable and has no delete API or control.

Available employees receive incoming requests as interactive LB Phone notifications. Requests can be declined with `-` or accepted with `+` directly from the notification without opening Services+ first; the in-app incoming request view provides the same controls.

When the phone is usable and no native call is active, an incoming request brings the phone and Services+ offer screen on screen. The default request keybinds mirror LB Phone calls: `ENTER` accepts and `BACKSPACE` declines. They are separate FiveM key mappings so players can change them in GTA settings without modifying LB Phone.

Category request definitions are data-driven in `shared/request_definitions.lua`. Category-specific `specialized` templates appear first and expose minimal fields for pickup, roadside/towing assistance, delivery, table reservations, medical transport, property viewing, legal assistance and police requests. Every company then receives one `general` request with a freely written subject and description for appointments, complaints, information, callbacks or any other concern. Select options are allow-listed and validated server-side. Phone fields are prefilled from the currently equipped LB Phone number but remain ordinary editable text fields. Add a field definition, template, category mapping, and phase set to introduce another controlled workflow without changing request rendering. Company-specific choices remain stored in `services_plus_company_request_settings`; obsolete or unknown templates, fields and phases are rejected or safely replaced with valid defaults.

Citizens receive live in-app updates and LB Phone notifications when their request is accepted, returned, moved to another phase, completed, cancelled or deleted. Active requests are shown separately from request history. Request navigation can be disabled, offered as a notification action, or set automatically for the successful assignee; coordinates are derived server-side through OneSync and sent only after assignment.

Trusted MDT, dispatch and business resources can use the allow-listed server exports documented in `API.md`. Add resource names to `Config.ApiAllowedResources`. Do not invoke Services+ internal network events from another resource.

Set `Config.RequireEquippedPhone = false` only for development environments where LB Phone has no equipped-phone concept available.

Optional integrations are disabled by default. See `INTEGRATIONS.md` before adding an adapter.

## Database Changes

Schema changes are versioned in `sql/migrations/`. Before applying any production migration:

1. Stop `services-plus`.
2. Create a database backup.
3. Apply the migration in version order.
4. Start `services-plus` and verify the reported schema version.

Rollback requires restoring the pre-migration backup. Do not drop Services+ tables on a production database without a verified backup.

Existing installations must apply migrations through `sql/migrations/007_phase2_number_staffing_notifications_navigation_api.sql` before restarting the resource. Migration 004 adds call queues, per-number conversations/messages/read state, and Phase 2 request lifecycle columns. Migration 005 adds persistent per-user message reactions. Migration 006 adds audited soft deletion for requests, shared-inbox conversations and individual messages. Migration 007 adds granular number operations, line subscriptions, request target numbers, navigation coordinates and idempotent external references. Active requests are safely returned and active calls are ended after a resource restart.

## Development Checks

Run from `ui/`:

```sh
npm run typecheck
npm run lint
npm test
npm run build
```

The frontend can be opened through the Vite development server. Browser mode provides isolated mock data for directory, duty, request, activity and administration UI testing.
