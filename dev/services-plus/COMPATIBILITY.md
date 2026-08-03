# Compatibility

Services+ is an independent resource. It uses supported exports and events and does not modify LB Phone, framework, dispatch, billing, inventory, notification, or map resources.

## Matrix

| Component | Integration | Automated coverage | Live-server validation |
| --- | --- | --- | --- |
| LB Phone | Required dependency, custom app, calls, messages, notifications, gallery and contacts | Contract/static checks | Required before production |
| oxmysql | Required dependency and awaited parameterized queries | Schema and contract checks | Required before production |
| ESX | Public shared-object and player APIs | Adapter static checks | Required before production |
| QBCore | Public core-object and player APIs | Adapter static checks | Required before production |
| Qbox | Public `qbx_core` player export | Adapter static checks | Required before production |
| Standalone | License-based configured identity | Adapter static checks | Required when enabled |
| Dispatch/billing/inventory/notification/map | Optional adapter boundary only | Missing-resource fallback contract | Test each enabled adapter |

The release candidate does not claim compatibility with an untested fork solely because it shares a framework name. Confirm the exact server versions in `RELEASE_CHECKLIST.md`.

## Ownership Boundaries

- LB Phone owns phone audio, native calls, messages, contacts, media selection, and phone presentation.
- Frameworks own player identity, jobs, grades, and administrator roles.
- Services+ owns company configuration, duty state, call/request coordination, shared-inbox projections, and workflow metadata.
- External MDT/dispatch systems own patrols, multiple officers, vehicles, radio state, and live tracking. They correlate through the request ID and `API.md` contracts.

Resource start and stop handling is event-driven. Required dependency failures stop initialization with a console error. Missing optional integrations log a warning and leave the core resource available.

