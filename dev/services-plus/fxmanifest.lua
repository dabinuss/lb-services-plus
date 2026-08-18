fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'services-plus'
author 'Dabi'
description 'Services+ - erweiterte Dienste-App fuer LB Phone'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
    'peekplus/shared/config.lua',
    'peekplus/shared/defaults.lua',
    'shared/categories.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/callback.lua',
    'client/main.lua',
    'peekplus/client/app.lua',
    'peekplus/client/lbphone.lua',
    'peekplus/client/controller.lua',
    'peekplus/client/api.lua',
    'peekplus/client/history.lua',
    'client/services/requests.lua',
    'peekplus/client/debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/callback.lua',
    'server/util.lua',
    'server/framework.lua',
    'peekplus/server/settings.lua',
    'server/companies.lua',
    'server/employees.lua',
    'server/calls.lua',
    'server/requests.lua',
    'server/admin.lua',
    'server/main.lua',
    'server/seed.lua',
    'server/api.lua',
}

-- The custom app itself (ui/dist) is loaded by lb-phone as a plain iframe
-- src via AddCustomApp's `ui` field (see client/main.lua) - it does NOT need
-- this resource's own ui_page. That slot is used by PeekPlus' Sibling-NUI
-- controller instead.
ui_page 'peekplus/ui/overlay/index-peekplus-1.2.2.html'

files {
    'peekplus/ui/overlay/index-peekplus-1.2.2.html',
    'peekplus/ui/overlay/overlay.js',
    'services/request-types/taxi/index.html',
    'services/request-types/taxi/taxi.css',
    'services/request-types/taxi/taxi.js',
    'services/request-types/taxi/fonts/DSEG7Classic-Regular.woff2',
    'services/request-types/taxi/fonts/DSEG14Classic-Regular.woff2',
    'services/request-types/taxi/fonts/DSEG-LICENSE.txt',
    'ui/dist/index.html',
    'ui/dist/**/*',
    'locales/*.json',
}

dependencies {
    'lb-phone',
    'oxmysql', -- server_scripts pulls in @oxmysql/lib/MySQL.lua directly (plan review round 4 §10)
}
