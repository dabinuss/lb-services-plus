# PeekPlus client API

PeekPlus is the generic notification and phone-peek layer shipped inside the
`services-plus` resource. Other resources do not install another resource and
must declare `services-plus` as a dependency or check that it is started.

All exports in this document are client-side. PeekPlus owns presentation,
queueing, input arbitration and cleanup only. It does not provide a generic
server delivery API or persist consumer state. Consumers decide how data
reaches their client and must validate every gameplay action on their server.

## Internal module layout

All PeekPlus-owned code is grouped below `peekplus/`:

- `shared/` contains configuration, defaults and validation limits.
- `client/` contains app registration, the controller, LB Phone adapter, API,
  history and tests.
- `server/` contains only the legacy settings fallback for LB Phone versions
  without the client-side `GetSettings` export.
- `ui/overlay/` is the cache-busted Sibling-NUI controller.
- `ui/notification-app/` contains the React source for local history.

Services+ consumes this module through its public client API. Its request
adapter remains in `client/services/requests.lua` because request gameplay is
owned by Services+, not by PeekPlus. The shared Vite entrypoints and compiled
`ui/dist/` output also remain under `ui/`; they are integration/build outputs,
not additional PeekPlus implementations.

The local Notifications app and its session history are enabled by default.
Set `Config.PeekPlusApp.enabled = false` in `peekplus/shared/config.lua` to
disable both. Peek cards, actions and all other PeekPlus functions continue to
work normally without the History app.

Local `peekplus_test*` development commands are registered only when
`Config.Debug = true` in `shared/config.lua`.

## Show a card

```lua
local peekId, err = exports["services-plus"]:ShowPeek({
    key = "medical:incident:42",
    title = "Medical Emergency",
    subtitle = "Pillbox Medical",
    description = "2 injured people · Legion Square",
    duration = 15000,
    variant = "warning",
    template = "action",
    history = true,
    sound = true,
    priority = 0,
    actions = {
        { id = "decline", label = "Decline", key = "BACK", color = "danger" },
        { id = "accept", label = "Accept", key = "RETURN", color = "success" },
    },
})
```

The invoking resource becomes the owner automatically. A supplied `owner`
field is ignored. Text is bounded and rendered as text, never as HTML.

Card options:

- `key`: optional owner-local logical key. Showing the same key again updates
  the existing card instead of creating a duplicate.
- `state`: `pending` or `active` when created.
- `duration`: milliseconds; `-1` means no automatic expiry.
- `hold`: keeps the phone in peek until the card is changed or removed;
  defaults to `true` for an `active` card.
- `sound`: plays at most once for this card and respects LB-Phone settings.
- `priority`: bounded queue priority.
- `interrupt`: only a strictly higher-priority card may temporarily suspend a
  held card. The held card returns without another sound.
- `actions`: up to the configured maximum. Version 1 supports the optional
  keys `RETURN` and `BACK`.
- `variant`: semantic styling: `neutral`, `info`, `success`, `warning` or
  `error`.
- `layout`: content model: `text`, `details`, `actions`, `progress`, `timer`
  or the `custom` layout selected by a registered iframe template.
- `template`: visual renderer. Built-ins are `default`, `compact`, `detail`,
  `action`, `progress` and `timer`.
- `history`: `false` excludes this card from the local history; it defaults
  to `true`.
- `icon`: optional semantic card icon such as `taxi`, `medical`, `police`, or `wrench`.
- `iconUrl`: optional HTTPS image URL shown as the card icon; `icon` remains its fallback.
- `details`: up to the configured number of `{ label, value, icon? }` rows. If every row has an icon, PeekPlus uses the compact icon/value layout and keeps labels as accessibility text.
- `progress`: `{ value, max, label }` for a progress layout.
- `timer`: `{ elapsed, duration, countdown, label }`, using milliseconds.

PeekPlus registers `PeekPlus: Primäraktion ausführen` and `PeekPlus:
Benachrichtigung ablehnen/abbrechen` in FiveM's key binding settings. Their defaults are
`ENTER` and `BACKSPACE`. Consumers use the PeekPlus actions and must not register
a competing binding for the same card.

An action may require two-step confirmation:

```lua
{
    id = "cancel",
    label = "Cancel",
    key = "BACK",
    color = "danger",
    confirm = { label = "Confirm?", timeout = 5000 },
}
```

## Receive actions

Listen to the event scoped to the exact consumer resource name:

```lua
AddEventHandler("peekplus:action:my-resource", function(data)
    -- data.id
    -- data.action
    -- data.confirmed
    -- data.revision
    -- data.actionToken

    -- Ask your server to validate and perform the operation here.
end)
```

PeekPlus locks the card after dispatch so double-clicks and key repeat cannot
send the same action twice. After the authoritative operation succeeds,
update or remove the card. On failure, release the action lock:

```lua
exports["services-plus"]:ReleasePeekAction(data.id, data.actionToken)
```

Owner-scoped events prevent accidental cross-resource handling but are not a
security boundary against a modified client. The server remains authoritative.

## Update, inspect and remove

```lua
local ok, err = exports["services-plus"]:UpdatePeek(peekId, {
    state = "active",
    description = "Request accepted",
    duration = -1,
    hold = true,
    sound = false,
    actions = {
        {
            id = "cancel",
            label = "Cancel",
            key = "BACK",
            color = "danger",
            confirm = { label = "Confirm?", timeout = 5000 },
        },
    },
}, data.revision, data.actionToken)

-- Frequent display-only updates do not advance revisions or release actions:
exports["services-plus"]:UpdatePeekPresentation(peekId, {
    progress = { value = 72, max = 100, label = "Download" },
})

local card = exports["services-plus"]:GetPeek(peekId)
exports["services-plus"]:RemovePeek(peekId, data.revision, data.actionToken)
exports["services-plus"]:ClearPeeks()

local ownHistory = exports["services-plus"]:GetPeekHistory()
exports["services-plus"]:MarkPeekHistoryRead(historyId, true)
exports["services-plus"]:ClearPeekHistory(historyId) -- omit id to clear own history
```

A consumer can only access its own cards. Updates advance the card revision
and reject invalid state transitions. When responding to an action, pass its
revision and token as shown so a delayed response cannot overwrite or remove a
newer card state. Both arguments are optional for non-action-driven updates.
Stopping a consumer automatically clears only that consumer's cards.
`RemovePeek` accepts an optional fourth `reason` argument after revision and
action token. It is recorded in history and emitted through lifecycle events.

## History and presentation ownership

PeekPlus keeps a bounded local session history and presents it through the
separate **Notifications** app installed in LB Phone. Entries can be marked as
read, inspected and deleted. The app never contacts the server. History is not
authoritative and is intentionally lost when `services-plus` restarts. A
consumer that needs persistence owns it and rehydrates PeekPlus itself.

Presentation extensions use three separate concepts:

- `variant` describes semantic styling such as neutral, info, success,
  warning or error.
- `layout` describes data requirements such as text, actions, details,
  progress or timer.
- `template` selects a concrete renderer. PeekPlus supplies standard
  templates; a consumer-specific feature such as a navigation live map uses
  an explicitly registered consumer template instead of being added to every
  PeekPlus installation.

Consumer resources can inspect and manage only their own history through
`GetPeekHistory`, `MarkPeekHistoryRead` and `ClearPeekHistory`. The
Notifications app can display the combined local history.

## Consumer templates

A consumer can register a resource-owned iframe renderer:

```lua
local templateId, err = exports["services-plus"]:RegisterPeekTemplate("live-map", {
    ui = "ui/live-map.html",
    height = 150,
    fullCard = false,
})

exports["services-plus"]:ShowPeek({
    key = "navigation:route",
    title = "Route guidance",
    template = templateId,
    templateData = { street = "Vespucci Boulevard", distance = "350 m" },
})
```

The UI path must belong to the invoking resource and be listed in that
resource's `files`. PeekPlus constructs the CFX URL, sandboxes the iframe,
limits its height and payload, and removes it with the owning resource.
Normal custom templates are passive and keep PeekPlus' standard card chrome.
Setting `fullCard = true` gives the iframe the complete bounded visual surface
and pointer input. PeekPlus still owns geometry, lifecycle, hotkeys,
confirmation state and server-facing action validation. The iframe receives:

```js
window.addEventListener('message', ({ data }) => {
    if (data?.type !== 'peekplus:template') return
    // data.template, data.data, data.presentation, data.actionEndpoint
    // and a bounded, validated data.card summary including actions.
})
```

A full-card renderer invokes an advertised action through `actionEndpoint`
with `{ id: card.id, revision: card.revision, action: action.id }`. PeekPlus
rejects stale cards and actions not declared on the currently visible card.

Arbitrary HTML is never accepted in a normal card payload. Unregister an
unused renderer with `UnregisterPeekTemplate(name)`. Active templates cannot
be unregistered until their cards are removed.

## Lifecycle events

PeekPlus emits a global event and an owner-scoped event for local lifecycle
changes:

```lua
AddEventHandler("peekplus:lifecycle:my-resource", function(data)
    -- data.id, data.key, data.revision, data.state, data.reason, data.removed
end)
```

Reasons include `created`, `queued`, `visible`, `updated`, `deduplicated`,
`suspended`, `resumed`, `expired`, `removed`, `owner_stopped` and a custom
removal reason supplied to `RemovePeek`. `data.removed` is `true` only for the
final lifecycle event after which the card no longer exists. `peekplus:ready`
is emitted whenever the controller NUI reconnects. These are local
presentation events, not trusted gameplay authorization.

Adapters for LB Phone's standard apps, for example a running stopwatch, are a
future extension. They should use stable app events or exports and must not
scrape another app's DOM.

## Phone lifecycle

- Exactly one PeekPlus card controls the closed-phone peek at a time.
- Closed-phone cards have a bounded compact layout: optional text and detail
  rows truncate before action buttons can leave the visible peek area.
- Card width is anchored to LB Phone's `.phone-container` display surface,
  never to the wider `.full-phone` housing; the display itself is the hard
  clipping boundary and cards may use exactly 100% of its inner width.
- Opening the phone releases its geometry and inserts the card into LB Phone's
  lockscreen notification stack when that stack exists.
- Home screens and apps are not covered.
- Calls retain visual and input priority; PeekPlus actions are suspended.
- Restarting LB Phone reconnects without replaying a sound.
- Stopping Services+ removes its DOM, styles, observers, timers and phone lock.
- `Config.PeekPlus.rootFallback` decides whether a card appears outside the
  phone when no usable phone exists.

The implementation depends on LB Phone's runtime DOM structure but never
patches LB Phone files. Missing capabilities fail safely to the configured
fallback.

An optional standalone consumer example is included at
`dev/examples/peekplus-consumer`. It depends only on `services-plus` and uses
the same public exports and owner-scoped action event documented above. When
that separate example resource is installed and started, run
`peekplus_test_consumer` in F8 to test the public consumer API.
