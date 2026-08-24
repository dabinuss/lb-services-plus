import './colors.css'
import './index.css'
import NotificationApp from '../../peekplus/ui/notification-app/NotificationApp.jsx'
import { LanguageProvider } from './lib/i18n.jsx'
import { mountApp } from './lib/mountApp.jsx'

mountApp(
  <LanguageProvider>
    <NotificationApp />
  </LanguageProvider>,
)
