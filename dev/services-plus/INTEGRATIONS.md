# Integration Boundaries

Services+ is a separate resource and only uses documented FiveM, LB Phone, framework and optional-resource APIs.

- `lb-phone` and `oxmysql` are required dependencies.
- ESX, QBCore and Qbox are detected through their public exports. Standalone mode uses explicit server configuration.
- Notification, dispatch, billing, inventory and map adapters are disabled by default.
- An enabled optional adapter is called only when its configured resource is running.
- A missing optional integration logs one warning and leaves the core workflow available.
- No third-party files, global framework state, jobs, inventories, invoices or map state are modified.
- External side effects must be added behind `integrations/server.lua`, with server-side permission checks and rate limits.

The Phase 1 prototypes observe documented LB Phone call and message events for diagnostics only. Call distribution and shared inbox behavior remain Phase 2 scope.
