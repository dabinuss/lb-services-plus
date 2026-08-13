# Services+ UI

React/Vite frontend for the Services+ LB-Phone custom app.

```bash
npm install
npm run dev     # http://localhost:5173, uses fixture data (see src/lib/nui.js)
npm run build   # writes dist/, which fxmanifest.lua ships as the app's ui_page
```

Use `http://localhost:5173/notifications.html` to preview the local PeekPlus
Notifications app with fixture history. Its source lives in
`../peekplus/ui/notification-app/`; `notifications.html` is only the shared
Vite entrypoint.

`npm run dev` renders without a running FiveM client (`window.invokeNative` is
absent, so `src/lib/nui.js` serves fixture data instead of talking to the
server). Once loaded inside the actual phone, it talks to `client/main.lua`'s
`RegisterNUICallback` handlers via the real `fetchNui`/`createCall`/`getSettings`
globals lb-phone injects.

Run `npm run build` after every change before testing in-game - the resource
serves `ui/dist`, not `ui/src`.
