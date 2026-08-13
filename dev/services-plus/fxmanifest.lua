fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'services-plus'
author 'Dabi'
description 'Services+ - erweiterte Dienste-App fuer LB Phone'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
    'shared/categories.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/callback.lua',
    'client/main.lua',
    'client/overlay.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/callback.lua',
    'server/util.lua',
    'server/framework.lua',
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
-- this resource's own ui_page. That slot is used by the Sibling-NUI overlay
-- controller instead (client/overlay.lua + SIBLING-NUI.md).
ui_page 'ui/overlay/index-peek-20260812-14.html'

files {
    'ui/overlay/index.html',
    'ui/overlay/index-peek-20260812-14.html',
    'ui/overlay/overlay.js',
    'ui/dist/index.html',
    'ui/dist/**/*',
    'locales/*.json',
}

dependencies {
    'lb-phone',
    'oxmysql', -- server_scripts pulls in @oxmysql/lib/MySQL.lua directly (plan review round 4 §10)
}
