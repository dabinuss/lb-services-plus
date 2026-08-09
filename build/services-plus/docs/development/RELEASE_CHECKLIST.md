# Release Candidate Validation

Version: `0.7.0-rc1`

## Automated Gates

- [x] TypeScript type checking
- [x] ESLint with zero warnings
- [x] Component and logic tests
- [x] Phase 1, Phase 2, Phase 3, and Phase 4 contract tests
- [x] Lua parsing/static checks
- [x] Production frontend build
- [x] Browser smoke tests at compact and desktop viewports
- [x] Production manifest excludes `server/prototypes.lua`
- [x] API exports, events, app actions, push types, examples, and documentation links match source inventory
- [x] Generated API inventory matches `shared/api_contracts.json`

Local validation re-run on 2026-08-03 for the 0.7.0-rc1 change set: 17 UI tests, TypeScript type checking, linting, production build, Lua static checks, generated API metadata checks, pagination model checks, and all four phase contract suites passed on Node `22.23.2` with a clean `npm ci`. TypeScript, linting, the production build, and every contract/phase suite also passed independently on Node `20.16.0`. The Vitest component/logic suite requires Node's `require(esm)` support (Node `20.19+` or `22.12+`) because jsdom's transitive dependencies are now ESM-only, so it cannot start on Node `20.16.0`; use `20.19+`/`22.12+` for that suite. Live FiveM validation remains required.

Record command results in the release commit or deployment ticket. A checked item must correspond to the exact files being deployed.

## Live FiveM Gates

- [ ] Current LB Phone: app registration, restart, native and NUI audio modes
- [ ] ESX workflow
- [ ] QBCore workflow
- [ ] Qbox workflow
- [ ] Standalone workflow when enabled
- [ ] Citizen, employee, dispatch, leader, administrator, and unauthorized permissions
- [ ] Duplicate call and request acceptance under latency
- [ ] Resource restart, LB Phone restart, server restart, character switch, and database reconnect
- [ ] Multiple calls, queue limit, empty states, missing images, and long names
- [ ] Light and dark phone themes
- [ ] Missing optional-resource fallback and every enabled adapter
- [ ] More than 50 requests, calls, and conversations: load every page without gaps or duplicate IDs
- [ ] Conversation receives new activity between page loads: composite cursor still reaches all older rows
- [ ] Rapid refresh, tab pagination, and inbox switching under injected latency: stale responses never replace newer state
- [ ] Badge totals match direct database counts for unread messages, unanswered requests, and unseen calls
- [ ] Every configured upload provider host is accepted and an unlisted host is rejected

For every framework/LB Phone combination, record the exact resource versions, server artifact, database version, OneSync mode, test date, tester, result, and evidence link. A framework family name without exact versions is not compatibility evidence.

## Performance Record

Capture the server artifact, client count, company count, test dataset size, and profiler duration with each result.

| Measurement | Idle | App open / active workflow | Acceptance decision |
| --- | --- | --- | --- |
| Client `resmon` | Not measured | Not measured | Pending live server |
| Server profiler | Not measured | Not measured | Pending live server |
| Database queries per action | Static review only | Static review only | Pending instrumentation |
| Network payload/event count | Static review only | Static review only | Pending instrumentation |
| UI memory and render count | Not measured | Not measured | Pending browser profiling |

## Release Decision

Do not promote this release candidate to a production release until all applicable live gates have evidence, no critical or high-severity issue remains, and database restore has been rehearsed. The generated API inventory and automated documentation review must be complete for API version 11.
