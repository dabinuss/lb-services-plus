# Services+ Phase 1

Services+ is a separate LB Phone custom app resource providing a searchable company directory and a server-authoritative employee duty portal.

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

Server administrators can create, edit and delete companies, configure logos, card backgrounds, all company numbers, and global call/request availability. Company leaders can change operational request/message toggles and the dispatch mode. Active team contact actions resolve phone numbers server-side and use LB Phone's documented call/contact APIs.

Set `Config.RequireEquippedPhone = false` only for development environments where LB Phone has no equipped-phone concept available.

Optional integrations are disabled by default. See `INTEGRATIONS.md` before adding an adapter.

## Database Changes

Schema changes are versioned in `sql/migrations/`. Before applying any production migration:

1. Stop `services-plus`.
2. Create a database backup.
3. Apply the migration in version order.
4. Start `services-plus` and verify the reported schema version.

Rollback for Phase 1 requires restoring the pre-migration backup. Do not drop Services+ tables on a production database without a verified backup.

Existing Phase 1 installations must apply migrations through `sql/migrations/003_company_cards_and_dispatch.sql` before restarting the resource.

## Development Checks

Run from `ui/`:

```sh
npm run typecheck
npm run lint
npm test
npm run build
```

The frontend can be opened through the Vite development server. Browser mode provides isolated mock data for directory, duty, request, activity and administration UI testing.
