# Phase 1 Technical Prototypes

The Phase 1 integration prototypes were checked against the official LB Phone and FiveM documentation before implementation.

## Results

1. **Custom app registration:** `AddCustomApp` accepts the Services+ identifier and `web/index.html`; return values are checked.
2. **Resource restart:** `RemoveCustomApp` runs when Services+ stops. A local registration guard prevents duplicate calls.
3. **Company numbers:** configuration and persistence support multiple native numbers per company. `CreateCustomNumber` and `RemoveCustomNumber` are isolated in the client integration adapter for Phase 2 routing.
4. **Call lifecycle:** documented `lb-phone:newCall`, `lb-phone:callAnswered`, and `lb-phone:callEnded` server events are observed in debug mode without changing calls.
5. **Company messages:** the documented `lb-phone:newCompanyMessage` event is observed in debug mode without claiming inbox ownership.
6. **Multiple numbers:** every number has its own identifier, label, distribution mode and shared-inbox flag; the database enforces number uniqueness.
7. **Shared inbox:** Phase 1 stores the dedicated-inbox setting and reserves assignment persistence. Message routing remains Phase 2 scope.
8. **NUI focus:** Services+ relies on LB Phone's custom-app iframe and does not call `SetNuiFocus`, preventing focus conflicts.
9. **LB Phone restart:** the client clears its registration guard and re-registers after the documented startup delay.
10. **Framework jobs:** ESX, QBCore and Qbox data are normalized behind one server bridge. Standalone mappings use license identifiers.
11. **Optional integrations:** configured resources are checked with `GetResourceState` before use.
12. **Missing optional resources:** one warning is logged and core company/duty behavior remains available.

References:

- https://docs.lbscripts.com/phone/custom-apps/
- https://docs.lbscripts.com/phone/exports/client-exports/
- https://docs.lbscripts.com/phone/exports/server-events/
- https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- https://docs.fivem.net/docs/developers/server-security/
