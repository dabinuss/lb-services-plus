# LB Phone documentation snapshot

Fetched from https://docs.lbscripts.com/phone/ on 2026-08-04, for local reference when
implementing/auditing the Services+ custom app. Only the pages relevant to a custom app
integration are captured (not the full phone documentation).

## Custom Apps (`/phone/custom-apps/`)

LB Phone allows you to add apps that either have a UI or simply trigger functions when
opening the app. Function-only apps are registered in `lb-phone/config/config.lua` via
`Config.CustomApps`:

```lua
Config.CustomApps = {
    ["app_identifier"] = {
        name = "App Name",
        description = "App Description",
        developer = "LB Phone", -- OPTIONAL
        defaultApp = true, -- OPTIONAL, app added without downloading
        game = false, -- OPTIONAL, adds app to the game section
        size = 59812, -- OPTIONAL, kB
        images = { "https://example.com/photo.jpg" }, -- OPTIONAL
        ui = "resource-name/ui/index.html", -- OPTIONAL
        icon = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/icon.png", -- OPTIONAL
        price = 0, -- OPTIONAL, in-game money to download
        landscape = false, -- OPTIONAL
        keepOpen = true, -- OPTIONAL, only works if ui is not defined
        onUse = function() end, -- OPTIONAL client
        onServerUse = function(source) end -- OPTIONAL server
    }
}
```

### Custom apps using UI

Create a separate script, provide the HTML file path as `ui`. Recommended: build with
exports, using LB's template apps as reference.

- If dark mode is enabled, `data-theme` is set to `dark` on the page, else `light`.
- **Adding the app**: use the `AddCustomApp` export.
- **Removing the app**: use the `RemoveCustomApp` export.
- **Sending a message to the UI**: use `SendCustomAppMessage`, NOT `SendNUIMessage`. Listen
  for it in the frontend the same way as `onNuiEvent`.

**Best practice — load initial data from the UI, not from `onOpen`:**
`onOpen` runs when the phone opens the app, but the iframe may still be loading, so a
message sent there can arrive before the UI is ready. Instead, register a NUI callback
client-side and have the UI request data once it has mounted, via `fetchNui`.

```lua
RegisterNUICallback("getDashboardData", function(_, cb)
    cb({ displayName = "John Doe", balance = 1000 })
end)
```

```ts
const data = await fetchNui<DashboardData>('getDashboardData')
```

`fetchNui` automatically targets the resource that registered the app. Use
`SendCustomAppMessage` for later push updates after the UI has loaded.

### Imported globals

When the app loads on the phone, a few functions/objects are imported into `globalThis`
**of the iframe LB Phone itself creates** for the app:

| Name | Type | Description |
|---|---|---|
| `resourceName` | string | The resource that added the custom app |
| `appName` | string | The app name |
| `settings` | object | The phone's settings |
| `components` | object | Useful UI components for the app |

Functions: `fetchNui(event, data, scriptName?)`, `onNuiEvent(event, handler)`,
`onSettingsChange(handler)`, `createCall({ number | company, videoCall?, hideNumber? })`.

**This confirms: these globals are injected only into LB Phone's own iframe.** A resource
that also declares its own `ui_page` in `fxmanifest.lua` gets a second, independent NUI
frame that never receives this injection — this was the root cause of the Services+
fullscreen-app bug (fixed by removing `ui_page`).

## Client Exports (`/phone/exports/client-exports/`) — Custom apps section

```lua
---@class CustomApp
---@field identifier string
---@field ui string
---@field name string
---@field description string
---@field images? string[]
---@field developer? string
---@field defaultApp? boolean
---@field size? number
---@field icon? string
---@field price? number
---@field landscape? boolean
---@field game? boolean
---@field disableInAppNotifications? boolean
---@field onDelete? fun()
---@field onInstall? fun()
---@field onUse? fun()
---@field fixBlur? boolean -- If true, the app will not be blurry. Requires em/rem CSS units.
---@field onClose? fun()
---@field onOpen? fun()
---@param appData CustomApp
---@return boolean success
---@return string? errorMessage
exports["lb-phone"]:AddCustomApp({ identifier = "custom-app", name = "Custom App", description = "...", ui = "ui/index.html" })
```

> "Make sure to wait for lb-phone to be started, and then wait a bit more (e.g. 500ms) to
> make sure the export exists."

`RemoveCustomApp(identifier)`, `SendCustomAppMessage(identifier, data)`.

**`fixBlur` clarified**: `true` = crisp iframe rendering but *requires* the app's CSS to use
`em`/`rem` units (LB Phone changes how it sizes/scales the iframe). `false`/unset = default
scaled iframe (slightly blurry, but works with regular `px` CSS). Services+'s CSS is
px-based, so `fixBlur = false` is the correct setting here, not a workaround — it does not
require em/rem units.

## Server Exports (`/phone/exports/server-exports/`) — Calls section

```lua
---@class CallData
---@field callId number
---@field started number -- os.time() when the call started
---@field answered boolean
---@field videoCall boolean
---@field hideCallerId boolean
---@field company? string
---@field caller { source: number, number: string, nearby: number[] }
---@field callee { source?: number, number?: string, nearby: number[] }
---@param callId number
---@return CallData?
local call = exports["lb-phone"]:GetCall(callId)

---@param source number
---@return boolean success
exports["lb-phone"]:EndCall(source)
```

`CreateCall(caller, callee?, options?)` — for calls not shown on the phone UI (payphones
etc). `options.hideNumber` hides the caller's number for that created call.

`SendMessage(from, to, message, attachments?, cb?, channelId?)` returns
`{ channelId, messageId }`. `SendCoords(from, to, coords)`.

## Server Events (`/phone/exports/server-events/`)

```lua
-- message: { channelId: number, messageId: number, sender: string, recipient: string, message: string, attachments? string }
AddEventHandler("lb-phone:messages:messageSent", function(message) end)

-- message { company: string, sender: string, sentByEmployee: boolean, message: string, coords?: vector2, anonymous: boolean }
AddEventHandler("lb-phone:newCompanyMessage", function(message) end)

-- Triggered when a new call is made. See GetCall for the call data shape (CallData above).
AddEventHandler("lb-phone:newCall", function(call) end)

-- Triggered when a call is answered.
AddEventHandler("lb-phone:callAnswered", function(call) end)

---@param call table
---@param source number -- the person who ended the call
AddEventHandler("lb-phone:callEnded", function(call, source) end)
```

## Client Events (`/phone/exports/client-events/`)

No call- or message-related client events exist — `numberChanged`, `phoneToggled`,
`setOnScreen`, `toggleHud`, `phoneDied`, `settingsUpdated`, and social-media `newPost`
events only. Confirms Services+ correctly listens for calls/messages purely server-side.

## State Bags (`/phone/exports/state-bags/`)

| Name | Type | Description |
|---|---|---|
| `phoneOpen` | boolean | Whether the phone is open |
| `phoneNumber` | string | The equipped phone number |
| `phoneName` | string | The phone name |
| `flashlight` | boolean | Flashlight on/off |
| `speakerphone` | boolean | Speakerphone on/off |
| `mutedCall` | boolean | Own mute state during a call |
| `otherMutedCall` | boolean | Other party's mute state |
| `onCallWith` | number | Source the player is on a call with |
| `callAnswered` | boolean | Whether the current call has been answered |
| `instapicIsLive` | boolean | InstaPic live status |

Services+ uses its own private state bag key (`servicesPlusDuty`) — no collision with any
documented LB Phone key.

## App Configuration (`/phone/configuration/apps/`)

Covers LB Phone's *built-in* apps (renaming via locale files, removing via
`lb-phone/config/config.json` `apps` table, icon replacement). Not applicable to a custom
app like Services+, which registers itself at runtime via `AddCustomApp` instead.
