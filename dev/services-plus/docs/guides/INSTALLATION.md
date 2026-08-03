# Installation

## Requirements

- A current FiveM server with OneSync
- A current, supported LB Phone installation
- `oxmysql`
- ESX, QBCore, Qbox, or the configured standalone bridge
- MySQL 8 or MariaDB with JSON support

## New Installation

1. Stop the server and create a database backup.
2. Copy `services-plus` into the server resources directory without nesting it in another resource.
3. Import `sql/install.sql` once.
4. Review `config.lua`, especially `Config.Framework`, administrator access, leader grades, companies, and API allow-list entries.
5. Add the following resource order to `server.cfg`:

```cfg
ensure oxmysql
ensure lb-phone
ensure services-plus
```

6. Grant administrative access where required:

```cfg
add_ace group.admin servicesplus.admin allow
```

7. Start the server and confirm that the console reports `Services+ server initialized` without schema or dependency errors.
8. Complete the [runtime release checks](../development/RELEASE_CHECKLIST.md) before opening the resource to players.

The shipped `web/` directory is the production frontend. To rebuild it, run `npm ci` and `npm run build` in `ui/`. Do not deploy `ui/node_modules` or load `server/prototypes.lua` in production.

## Upgrade

Follow [database operations](DATABASE.md). Apply every missing migration in numeric order while `services-plus` is stopped, then deploy the matching resource version and restart it.

Set `Config.AllowedMediaDomains` to the exact hosts used by the configured LB Phone upload provider. Services+ validates syntax and reports an empty, invalid, or duplicate allow-list entry at startup. This check cannot discover the provider automatically; verify one real upload and one rejected unlisted host before release.
