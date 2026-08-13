import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import './colors.css'
import './index.css'
import App from './App.jsx'
import NotificationApp from '../../peekplus/ui/notification-app/NotificationApp.jsx'

// window.invokeNative only exists inside the actual FiveM NUI browser, so
// this is a reliable "am I running in a real phone" check (same trick the
// official lb-phone app template uses).
const devMode = !window.invokeNative

const root = createRoot(document.getElementById('root'))
const notificationMode = window.location.pathname.endsWith('/notifications.html')
  || new URLSearchParams(window.location.search).get('app') === 'peekplus'

const renderApp = () => {
  document.documentElement.style.visibility = 'visible'
  document.body.style.visibility = 'visible'

  root.render(
    <StrictMode>
      {notificationMode ? <NotificationApp /> : <App devMode={devMode} />}
    </StrictMode>,
  )
}

if (devMode) {
  renderApp()
} else {
  // In-game, lb-phone injects the shared `components` helpers into this
  // iframe asynchronously. Rendering before "componentsLoaded" arrives can
  // race against globals like fetchNui/createCall not existing yet.
  window.addEventListener('message', (event) => {
    if (event.data === 'componentsLoaded') renderApp()
  })
}
