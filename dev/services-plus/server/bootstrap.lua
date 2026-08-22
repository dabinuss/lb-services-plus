--[[
    Deterministic resource initialization. Module files only define their
    APIs; this is the single owner of database seeding and cache readiness.
]]

CreateThread(function()
    local ok, err = pcall(function()
        -- Categories must exist before request types resolve their category
        -- keys. Companies.Initialize owns that seed and its first cache load.
        Companies.Initialize()

        -- Optional development data runs after categories exist and before
        -- request types are seeded. It returns true when company rows changed.
        if SeedTestData.Run() then
            Companies.Reload()
        end

        Requests.Initialize()
    end)

    if not ok then
        ServicesPlus.initializationError = tostring(err)
        print(("^1[services-plus] initialization failed: %s^7"):format(tostring(err)))
        return
    end

    ServicesPlus.ready = true
    TriggerEvent("services-plus:internal:ready")
    print("^2[services-plus] initialization complete^7")
end)
