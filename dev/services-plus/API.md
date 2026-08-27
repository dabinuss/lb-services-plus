# Services+ Server API

Services+ exposes a small server-side API for other FiveM resources. Use
these exports instead of accessing Services+ database tables, callbacks,
routing functions, or runtime caches directly.

All examples below must run on the server. Lifecycle events are local server
events and are not registered as network events.

## Requests

### CreateRequestForPlayer

Creates and distributes a request using the same validation, competition,
routing, eligibility, and notification logic as the Services+ app.

```lua
local result = exports["services-plus"]:CreateRequestForPlayer(
    source,
    "medical",
    {
        description = "2 injured persons",
        passengerCount = 2,
    }
)

if not result then
    return
end

print(result.id, result.reached)
```

Parameters:

- `source` (`number`): online player source. The phone number and current
  position are resolved internally.
- `requestType` (`number|string`): request-type ID, technical identifier such
  as `medical_emergency`, or category key such as `medical`. Identifiers are
  unique and remain unchanged when an admin renames a request type.
- `options` (`table`, optional):
  - `description` (`string`, optional)
  - `passengerCount` (`number`, optional)
  - `companyJob` (`string`, optional): explicitly target a company in the
    request type's category.
  - `companyId` (`number`, optional): ID alternative to `companyJob`.

When no company is supplied, Services+ selects an enabled company from the
request type's category, preferring one that is currently available.
Competition request types are still distributed to all eligible companies in
their category.

Returns `false` when validation or creation fails. On success it returns:

```lua
{
    id = 123,
    reached = true, -- at least one eligible employee was notified
    request = requestObject,
}
```

### GetRequest

Returns a sanitized request or `nil` when it does not exist.

```lua
local request = exports["services-plus"]:GetRequest(123)
```

### GetActiveRequest

Returns the active request assigned to an online employee or `nil`.

```lua
local request = exports["services-plus"]:GetActiveRequest(source)
```

This also applies the normal reconnect/grace-period handling used by the
Services+ overlay.

### CancelRequest

Cancels an open or active request through the normal Services+ lifecycle.
Notifications are dismissed, an assigned employee's overlay is closed, and
the cancellation event is emitted.

```lua
local cancelled = exports["services-plus"]:CancelRequest(123)
```

Returns `true` when the request was cancelled, otherwise `false`.

### CompleteRequest

Completes an active request, closes the assigned employee's overlay, and
emits the completion event.

```lua
local completed = exports["services-plus"]:CompleteRequest(123)
```

Returns `true` when the request was completed, otherwise `false`.

## Sanitized request object

Request exports and lifecycle events use this shape. Framework identifiers
and internal routing data are intentionally omitted.

```lua
{
    id = 123,
    type = "medical_emergency",
    typeId = 4,
    typeName = "Medical Emergency",
    category = "medical",
    categoryId = 2,
    status = "open", -- open | active | completed | cancelled

    company = {
        id = 1,
        job = "ambulance",
        name = "EMS",
        icon = "https://cdn.fivemanage.com/company/icon.png",
    }, -- nil until a competition request is accepted

    requesterNumber = "5551234",
    employeeSource = 42, -- online session source only; otherwise nil
    position = { x = 123.4, y = 567.8 },
    passengerCount = 2,
    countLabel = "Number of injured people",
    description = "2 injured persons",
    createdAt = "2026-08-12 12:00:00",
    updatedAt = "2026-08-12 12:01:00",
}
```

## Request lifecycle events

Listen to local server events to react to state changes without polling:

```lua
AddEventHandler("services-plus:requestCreated", function(request)
end)

AddEventHandler("services-plus:requestAccepted", function(request)
    if request.category == "medical" then
        -- Integrate with an MDT or medical system.
    end
end)

AddEventHandler("services-plus:requestCompleted", function(request)
end)

AddEventHandler("services-plus:requestCancelled", function(request)
end)

AddEventHandler("services-plus:requestExpired", function(request)
end)
```

`requestExpired` is emitted when an old open request expires. The same state
change also emits `requestCancelled` because the final stored status is
`cancelled`.

## Companies

### GetCompany

Returns public data for an enabled company or `nil`.

```lua
local company = exports["services-plus"]:GetCompany("ambulance")
```

Result:

```lua
{
    id = 1,
    job = "ambulance",
    name = "EMS",
    categoryId = 2,
    icon = "https://cdn.fivemanage.com/company/icon.png",
    background = "https://cdn.fivemanage.com/company/background.png",
    available = true,
    callsEnabled = true,
    messagesEnabled = true,
    requestsEnabled = true,
}
```

Remote company media is returned only when it is a valid HTTPS URL accepted
by LB Phone's configured media hostname/domain policy. Disallowed legacy or
seed values are exposed as `nil`; the stored database value is not deleted.

### IsCompanyAvailable

Returns whether an enabled company currently has at least one employee who
is on duty and has the Services+ status `available`.

```lua
if exports["services-plus"]:IsCompanyAvailable("taxi") then
    -- Taxi service is available.
end
```

### GetCompanyNumbers

Returns enabled public numbers for an enabled company. Unknown or disabled
companies return an empty table.

```lua
local numbers = exports["services-plus"]:GetCompanyNumbers("ambulance")
```

Each number has this shape:

```lua
{
    id = 1,
    label = "Main",
    number = "911",
    isMain = true,
    callsEnabled = true,
    messagesEnabled = true,
}
```

## Employees

### GetEmployeeState

Returns the public Services+ state for an online employee or `nil`.

```lua
local state = exports["services-plus"]:GetEmployeeState(source)
```

Result:

```lua
{
    status = "available", -- available | busy | pause
    onDuty = true,
}
```

### SetEmployeeStatus

Changes an online employee's Services+ status through the normal update path.
This updates team views, request/call routing, and native LB-Phone company
calls synchronization.

```lua
local result = exports["services-plus"]:SetEmployeeStatus(source, "busy")
```

Allowed status values are `available`, `busy`, and `pause`. Returns `false`
for an invalid source, non-employee, or invalid status. On success:

```lua
{
    ok = true,
    onDuty = true,
    status = "busy",
}
```

## Messaging

### SendCompanyMessage

Sends a normal Services+ message from a company's main number. It never uses
or exposes an employee's private number.

```lua
local sent = exports["services-plus"]:SendCompanyMessage(
    "ambulance",
    "5551234",
    "An ambulance has been dispatched."
)
```

The company and main mailbox must be enabled. Messages must contain between
1 and 1000 characters. Returns `true` on success, otherwise `false`.

## Intentionally private systems

The public API does not expose admin mutations, boss assignment, eligible
employee lists, routing targets, hotline internals, framework identifiers,
raw SQL helpers, or internal caches. These remain implementation details so
routing and framework support can change without breaking integrations.
