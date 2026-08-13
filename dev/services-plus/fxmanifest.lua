fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'services-plus'
author 'Dabi'
description 'Services+ - erweiterte Dienste-App fuer LB Phone'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
    'shared/peekplus.lua',
    'shared/categories.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/callback.lua',
    'client/main.lua',
    'client/peekplus/lbphone.lua',
    'client/peekplus/controller.lua',
    'client/peekplus/api.lua',
    'client/peekplus/history.lua',
    'client/services/requests.lua',
    'client/peekplus/debug.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/callback.lua',
    'server/util.lua',
    'server/framework.lua',
    'server/peekplus.lua',
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
-- controller instead. The legacy client/overlay.lua remains an unloaded
-- migration reference until final acceptance.
ui_page 'ui/overlay/index-peekplus-1.1.7.html'

files {
    'ui/overlay/index-peekplus-1.1.7.html',
    'ui/overlay/overlay.js',
    'ui/dist/index.html',
    'ui/dist/**/*',
    'locales/*.json',
}

dependencies {
    'lb-phone',
    'oxmysql', -- server_scripts pulls in @oxmysql/lib/MySQL.lua directly (plan review round 4 §10)
}
