fx_version "cerulean"
game "gta5"

author "Services+"
description "Company directory and duty portal for LB Phone"
version "0.1.0-phase1"

lua54 "yes"

ui_page "web/index.html"

files {
    "web/index.html",
    "web/assets/*",
    "web/icon.svg"
}

shared_scripts {
    "shared/constants.lua",
    "shared/categories.lua",
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
    "integrations/server.lua",
    "server/logger.lua",
    "server/rate_limiter.lua",
    "server/migrations.lua",
    "server/repository.lua",
    "server/companies.lua",
    "server/employees.lua",
    "server/api.lua",
    "server/events.lua",
    "server/prototypes.lua",
    "server/main.lua"
}

dependencies {
    "lb-phone",
    "oxmysql"
}
