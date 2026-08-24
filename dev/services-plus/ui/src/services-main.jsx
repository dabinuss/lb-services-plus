import './colors.css'
import './index.css'
import App from './App.jsx'
import { LanguageProvider } from './lib/i18n.jsx'
import { mountApp } from './lib/mountApp.jsx'

mountApp(
  <LanguageProvider>
    <App devMode={!window.invokeNative} />
  </LanguageProvider>,
)
