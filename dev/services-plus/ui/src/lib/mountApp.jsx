import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

export function mountApp(app) {
  const root = createRoot(document.getElementById('root'))
  const render = () => {
    document.documentElement.style.visibility = 'visible'
    document.body.style.visibility = 'visible'
    root.render(<StrictMode>{app}</StrictMode>)
  }

  if (!window.invokeNative) {
    render()
    return
  }

  // lb-phone injects helpers such as fetchNui/createCall asynchronously.
  const onComponentsLoaded = (event) => {
    if (event.data !== 'componentsLoaded') return
    window.removeEventListener('message', onComponentsLoaded)
    render()
  }

  window.addEventListener('message', onComponentsLoaded)
}
