# Integration Boundaries

Services+ is a separate resource and only uses documented FiveM, LB Phone, framework and optional-resource APIs.

- `lb-phone` and `oxmysql` are required dependencies.
- ESX, QBCore and Qbox are detected through their public exports. Standalone mode uses explicit server configuration.
- Notification, dispatch, billing, inventory and map adapters are disabled by default.
- An enabled optional adapter is called only when its configured resource is running.
- A missing optional integration logs one warning and leaves the core workflow available.
- No third-party files, global framework state, jobs, inventories, invoices or map state are modified.
- External side effects must be added behind `integrations/server.lua`, with server-side permission checks and rate limits.

Phase 2 uses documented LB Phone custom-number callbacks, call lifecycle events, messaging exports, notification exports and contact APIs. Services+ does not replace LB Phone audio, messages or contacts; it coordinates company permissions and persists its own workflow metadata.

Message attachments are selected through the custom-app `components.setGallery` API. LB Phone remains responsible for gallery access and configured media uploads; Services+ only validates and forwards the selected HTTPS URLs. Emoji messages use ordinary LB Phone message text, while Services+-specific message reactions are stored in the Services+ database.

Company calls remain native LB Phone calls under both native and NUI audio configurations. Existing optional dispatch, billing, notification, inventory and map resources are untouched unless a disabled-by-default adapter is explicitly configured. Adapters must degrade gracefully across resource start/stop order changes.

Trusted server resources use the exports in `API.md` and must be listed in `Config.ApiAllowedResources`. External request creation requires a stable `externalId`; Services+ scopes it to the invoking resource and returns the existing request when retried. Integration resources should consume local lifecycle events and must not call Services+ client/server network events directly.

Services+ exposes one primary request assignee and a stable `services-plus:server:requestLifecycle` event. MDT and dispatch resources remain responsible for patrol units, multiple assigned officers, vehicle and officer live locations, radio state and map presentation. They should correlate that state using the Services+ request ID and employee identifier, and use the validated request action exports when synchronizing lifecycle changes back to Services+.

Services+ conversation deletion is intentionally local to the Services+ shared-inbox projection. It does not delete or rewrite native LB Phone messages. Equipped-number changes are consumed through the documented `lb-phone:numberChanged` event and invalidate active duty after server-side number verification.
