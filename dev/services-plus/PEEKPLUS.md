# PeekPlus client API

PeekPlus is the generic notification and phone-peek layer shipped inside the
`services-plus` resource. Other resources do not install another resource and
must declare `services-plus` as a dependency or check that it is started.

All exports in this document are client-side. PeekPlus owns presentation,
queueing, input arbitration and cleanup only. Consumers must validate every
gameplay action on the server.

## Show a card

```lua
local peekId, err = exports["services-plus"]:ShowPeek({
    title = "Medical Emergency",
    subtitle = "Pillbox Medical",
    description = "2 injured people · Legion Square",
    duration = 15000,
    sound = true,
    priority = 0,
    actions = {
        { id = "decline", label = "Decline", key = "DELETE", color = "danger" },
        { id = "accept", label = "Accept", key = "RETURN", color = "success" },
    },
})
```

The invoking resource becomes the owner automatically. A supplied `owner`
field is ignored. Text is bounded and rendered as text, never as HTML.

Card options:

- `state`: `pending` or `active` when created.
- `duration`: milliseconds; `-1` means no automatic expiry.
- `hold`: keeps the phone in peek until the card is changed or removed;
  defaults to `true` for an `active` card.
- `sound`: plays at most once for this card and respects LB-Phone settings.
- `priority`: bounded queue priority.
- `interrupt`: only a strictly higher-priority card may temporarily suspend a
  held card. The held card returns without another sound.
- `actions`: up to the configured maximum. Version 1 supports the optional
  keys `RETURN` and `DELETE`.

An action may require two-step confirmation:

```lua
{
    id = "cancel",
    label = "Cancel",
    key = "DELETE",
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
            key = "DELETE",
            color = "danger",
            confirm = { label = "Confirm?", timeout = 5000 },
        },
    },
}, data.revision, data.actionToken)

local card = exports["services-plus"]:GetPeek(peekId)
exports["services-plus"]:RemovePeek(peekId, data.revision, data.actionToken)
exports["services-plus"]:ClearPeeks()
```

A consumer can only access its own cards. Updates advance the card revision
and reject invalid state transitions. When responding to an action, pass its
revision and token as shown so a delayed response cannot overwrite or remove a
newer card state. Both arguments are optional for non-action-driven updates.
Stopping a consumer automatically clears only that consumer's cards.

## Phone lifecycle

- Exactly one PeekPlus card controls the closed-phone peek at a time.
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
