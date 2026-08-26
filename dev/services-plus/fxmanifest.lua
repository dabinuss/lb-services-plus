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
    'peekplus/shared/quick_action_policy.lua',
    'shared/categories.lua',
    -- Each of these appends its own request type to
    -- Config.DefaultRequestTypes (initialized just above) - must load after
    -- shared/categories.lua. Order relative to each other doesn't matter.
    'request-types/taxi/register.lua',
    'request-types/police_emergency/register.lua',
    'request-types/medical_emergency/register.lua',
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
    'server/unread.lua',
    'peekplus/server/settings.lua',
    'server/companies.lua',
    'server/employees.lua',
    'server/calls.lua',
    -- Generic per-request-type feature registry (server/features.lua) must
    -- load before any request-types/<type>/server.lua module, since those
    -- register themselves into it at load time. requests.lua only ever
    -- calls Features.OnAccept/OnComplete - it never names a feature module.
    'server/features.lua',
    'server/requests.lua',
    'request-types/taxi/server.lua',
    'server/admin.lua',
    'server/main.lua',
    'server/seed.lua',
    'server/api.lua',
    -- Must stay last: this is the only place that seeds and loads the caches,
    -- after every owning module and request-type feature has been registered.
    'server/bootstrap.lua',
}

-- The custom app itself (ui/dist) is loaded by lb-phone as a plain iframe
-- src via AddCustomApp's `ui` field (see client/main.lua) - it does NOT need
-- this resource's own ui_page. That slot is used by PeekPlus' Sibling-NUI
-- controller instead.
ui_page 'peekplus/ui/overlay/index-peekplus-1.2.2.html'

files {
    'peekplus/ui/overlay/index-peekplus-1.2.2.html',
    'peekplus/ui/overlay/overlay.js',
    'request-types/**/*',
    'ui/dist/index.html',
    'ui/dist/**/*',
    'locales/*.json',
}

-- Not enabled yet (discussion, plan for later): once individual request
-- types are meant to ship openly readable even from an escrow-packaged
-- build, list their folders here, e.g. 'request-types/taxi/**'. Every
-- request type already lives fully under its own request-types/<id>/
-- folder (UI card + feature server module), so this is a file-list change
-- only when that's actually decided - no further restructuring needed.
-- escrow_ignore_list {
-- }

dependencies {
    'lb-phone',
    'oxmysql', -- server_scripts pulls in @oxmysql/lib/MySQL.lua directly (plan review round 4 §10)
}
