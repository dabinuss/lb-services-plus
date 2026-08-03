# Release Candidate Validation

Version: `0.5.0-rc1`

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

Local validation completed on 2026-08-03: 13 UI tests, TypeScript type checking, linting, production build, central API metadata checks, and all four phase contract suites. Existing browser portal smoke evidence remains valid for the unchanged visual layout; live FiveM validation is still required.

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

Do not promote this release candidate to a production release until all applicable live gates have evidence, no critical or high-severity issue remains, and database restore has been rehearsed. The generated API inventory and automated documentation review are complete for API version 9.
