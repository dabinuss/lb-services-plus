SeedTestData = {}

-- Optional local-development company seed. The central bootstrap calls this
-- only after the normal category seed has completed, so category ids are
-- resolved by stable keys instead of assuming fixed auto-increment ids.
---@return boolean changed
function SeedTestData.Run()
    if not Config.SeedTestData then return false end

    local existing = MySQL.scalar.await("SELECT COUNT(*) FROM phone_services_plus_companies")
    if existing and existing > 0 then
        print("^3[Services+] Database already contains companies. Skipping dummy data seed.^0")
        return false
    end

    print("^2[Services+] Seeding dummy test companies...^0")

    local companies = {
        { job = "police", name = "Los Santos Police Department", category = "police", number = "911", label = "Emergency", background = "https://images.unsplash.com/photo-1596720426673-e4e142561d3f?auto=format&fit=crop&w=400&q=80" },
        { job = "ambulance", name = "Pillbox Medical", category = "medical", number = "912", label = "Emergency", background = "https://images.unsplash.com/photo-1587559070757-f72a388edbba?auto=format&fit=crop&w=400&q=80" },
        { job = "mechanic", name = "Los Santos Customs", category = "mechanic", number = "555-0100", label = "Workshop", background = "https://images.unsplash.com/photo-1562259929-b7e181d8d9b7?auto=format&fit=crop&w=400&q=80" },
        { job = "taxi", name = "Downtown Cab Co.", category = "taxi", number = "555-0200", label = "Dispatch", background = "https://images.unsplash.com/photo-1549315535-c34032d8b4dc?auto=format&fit=crop&w=400&q=80" },
    }

    for i = 1, #companies do
        local entry = companies[i]
        local background, backgroundValid = Companies.NormalizeMediaUrl(entry.background)
        if not backgroundValid then
            print(("^3[Services+] Ignoring disallowed dummy background for '%s'.^0"):format(entry.job))
        end
        local categoryId = MySQL.scalar.await(
            "SELECT id FROM phone_services_plus_categories WHERE `key` = ?",
            { entry.category }
        )
        if not categoryId then error(("missing seeded category '%s'"):format(entry.category)) end

        local success = MySQL.transaction.await({
            {
                [[
                    INSERT INTO phone_services_plus_companies
                        (job, name, category_id, boss_grade, background, enabled, calls_enabled, messages_enabled, requests_enabled)
                    VALUES (?, ?, ?, 100, ?, 1, 1, 1, 1)
                ]],
                { entry.job, entry.name, categoryId, background or json.null },
            },
            {
                [[
                    INSERT INTO phone_services_plus_numbers
                        (company_id, number, label, is_main, messages_enabled)
                    VALUES (LAST_INSERT_ID(), ?, ?, 1, 1)
                ]],
                { entry.number, entry.label },
            },
        })
        if not success then error(("could not seed company '%s'"):format(entry.job)) end
    end

    print("^2[Services+] Dummy test companies seeded!^0")
    return true
end
