# Configuration

All runtime configuration lives in `config.lua`. Database-managed companies and settings take precedence after the initial seed.

## Core

| Setting | Purpose |
| --- | --- |
| `Config.Framework` | `auto`, `esx`, `qbcore`, `qbox`, or `standalone` |
| `Config.Locale` | Default server locale |
| `Config.Debug` | Verbose diagnostic logging; keep `false` in production |
| `Config.LogLevel` | Minimum production log level: `debug`, `info`, `warning`, or `error` |
| `Config.RequireEquippedPhone` | Requires the player to possess the currently equipped LB Phone |
| `Config.ServerCallbackTimeoutMs` | Client request timeout; keep finite |
| `Config.MaxCompanies` | Administrative company limit |
| `Config.MaxQueueBroadcastEntries` | Maximum active entries included in one queue position pass |
| `Config.AdminAce` | ACE permission used by the administration UI |

`Config.Framework = "auto"` detects Qbox, then QBCore, then ESX, and otherwise uses standalone mode. Set an explicit value on production servers to make startup failures visible.

## Permissions

`Config.LeaderGrades` maps framework jobs to the minimum numeric leader grade. `Config.ExplicitLeaders` maps stable player identifiers to company IDs. Server administrators use the configured ACE or supported framework administrator roles. All important permissions are recalculated server-side.

## Companies

`Config.Companies` seeds only an empty company table. Subsequent changes belong in the protected administration UI. Company job names must be unique. Each number independently controls enabled state, calls, inbox, requests, citizen visibility, and call distribution.

## Limits and Integrations

`Config.RateLimits` contains every write or expensive network action. Do not remove entries when adding callbacks. `Config.ApiAllowedResources` is an exact allow-list for trusted server exports; never add untrusted or client-controlled names.

Optional integrations are disabled by default. Enable an adapter only after implementing its documented boundary in `integrations/server.lua`. Missing optional resources must not disable core Services+ workflows. See [integration boundaries](../reference/INTEGRATIONS.md) and the [API reference](../api/API.md).

## Standalone

`Config.StandalonePlayers` is keyed by a FiveM license identifier and provides `job`, numeric `grade`, `role`, and `name`. It is intended for controlled servers and testing, not as an identity database.
