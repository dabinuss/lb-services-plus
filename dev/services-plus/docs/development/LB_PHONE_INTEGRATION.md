# LB Phone Technical Integration

The integration contracts were checked against the official LB Phone and FiveM documentation before implementation and reviewed again for the Phase 4 API inventory.

## Results

1. **Custom app registration:** `AddCustomApp` accepts the Services+ identifier and `web/index.html`; return values are checked.
2. **Resource restart:** `RemoveCustomApp` runs when Services+ stops. A local registration guard prevents duplicate calls.
3. **Company numbers:** `CreateCustomNumber` and `RemoveCustomNumber` are isolated in the client adapter and synchronized with the employee's authorized company session.
4. **Call lifecycle:** documented `lb-phone:newCall` and `lb-phone:callEnded` events attach native calls to server-authoritative queue records; custom incoming-call accept callbacks complete the native handoff.
5. **Company messages:** documented message exports and `lb-phone:messages:messageSent`/`lb-phone:newCompanyMessage` events feed number-specific shared inboxes with duplicate-message protection.
6. **Multiple numbers:** every number has its own identifier, label, distribution mode and shared-inbox flag; the database enforces number uniqueness.
7. **Shared inbox:** conversations, messages and per-employee read positions are persisted per company number; number eligibility is rechecked for every protected action.
8. **NUI focus:** Services+ relies on LB Phone's custom-app iframe and does not call `SetNuiFocus`, preventing focus conflicts.
9. **LB Phone restart:** the client clears its registration guard and re-registers after the documented startup delay.
10. **Framework jobs:** ESX, QBCore and Qbox data are normalized behind one server bridge. Standalone mappings use license identifiers.
11. **Optional integrations:** configured resources are checked with `GetResourceState` before use.
12. **Missing optional resources:** one warning is logged and core company/duty behavior remains available.
13. **Media selection:** the custom-app `components.setGallery` component supplies image/video URLs; direct URL entry is not exposed to players.
14. **Message reactions:** reaction values are limited to ten predefined emojis and authorized against the conversation on every write.

References:

- https://docs.lbscripts.com/phone/custom-apps/
- https://docs.lbscripts.com/phone/exports/client-exports/
- https://docs.lbscripts.com/phone/exports/server-events/
- https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- https://docs.fivem.net/docs/developers/server-security/
