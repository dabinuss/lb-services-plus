fx_version "cerulean"
game "gta5"

author "Services+"
description "Company communication and request workflows for LB Phone"
version "0.7.0-rc1"

lua54 "yes"

-- No ui_page here on purpose: LB Phone embeds the custom app itself via its own
-- iframe, fetching these files through the cfx-nui- origin below. Declaring our
-- own ui_page would additionally spin up an independent, unmanaged NUI overlay
-- that LB Phone never focuses or sizes and that never receives its `fetchNui`
-- injection (LB Phone injects it only into the iframe's own contentWindow) -
-- verified directly in LB Phone's compiled UI bundle.

files {
    "web/index.html",
    "web/assets/*",
    "web/icon.svg",
    "shared/api_contracts.json"
}

shared_scripts {
    "shared/constants.lua",
    "shared/categories.lua",
    "shared/request_definitions.lua",
    "config.lua"
}

client_scripts {
    "client/state.lua",
    "client/callbacks.lua",
    "client/app.lua",
    "client/integrations.lua",
    "client/main.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "bridge/server.lua",
    "server/logger.lua",
    "integrations/server.lua",
    "server/rate_limiter.lua",
    "server/idempotency.lua",
    "server/contracts.lua",
    "server/migrations.lua",
    "server/repository.lua",
    "server/companies.lua",
    "server/employees.lua",
    "server/calls.lua",
    "server/inboxes.lua",
    "server/requests.lua",
    "server/api.lua",
    "server/exports.lua",
    "server/events.lua",
    "server/main.lua"
}

dependencies {
    "lb-phone",
    "oxmysql"
}
