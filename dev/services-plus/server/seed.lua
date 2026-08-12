CreateThread(function()
    if not Config.SeedTestData then return end
    Wait(2000)
    
    local existing = MySQL.scalar.await("SELECT COUNT(*) FROM phone_services_plus_companies")
    if existing and existing > 0 then
        print("^3[Services+] Database already contains companies. Skipping dummy data seed.^0")
        return
    end

    print("^2[Services+] Seeding dummy test data...^0")

    MySQL.insert.await("INSERT IGNORE INTO phone_services_plus_categories (id, `key`, name, icon) VALUES (1, 'police', 'Police', 'police'), (2, 'medical', 'Medical', 'medical'), (3, 'mechanic', 'Mechanic', 'wrench'), (4, 'taxi', 'Taxi', 'taxi')")

    MySQL.insert.await([[
        INSERT IGNORE INTO phone_services_plus_companies 
        (id, job, name, category_id, boss_grade, background, icon, enabled, calls_enabled, messages_enabled, requests_enabled) VALUES 
        (1, 'police', 'Los Santos Police Department', 1, 100, 'https://images.unsplash.com/photo-1596720426673-e4e142561d3f?auto=format&fit=crop&w=400&q=80', '', 1, 1, 1, 1),
        (2, 'ambulance', 'Pillbox Medical', 2, 100, 'https://images.unsplash.com/photo-1587559070757-f72a388edbba?auto=format&fit=crop&w=400&q=80', '', 1, 1, 1, 1),
        (3, 'mechanic', 'Los Santos Customs', 3, 100, 'https://images.unsplash.com/photo-1562259929-b7e181d8d9b7?auto=format&fit=crop&w=400&q=80', '', 1, 1, 1, 1),
        (4, 'taxi', 'Downtown Cab Co.', 4, 100, 'https://images.unsplash.com/photo-1549315535-c34032d8b4dc?auto=format&fit=crop&w=400&q=80', '', 1, 1, 1, 1)
    ]])
    
    MySQL.insert.await([[
        INSERT IGNORE INTO phone_services_plus_numbers (company_id, number, label, is_main, messages_enabled) VALUES
        (1, '911', 'Emergency', 1, 1),
        (2, '912', 'Emergency', 1, 1),
        (3, '555-0100', 'Workshop', 1, 1),
        (4, '555-0200', 'Dispatch', 1, 1)
    ]])

    MySQL.insert.await([[
        INSERT IGNORE INTO phone_services_plus_request_types (category_id, name, icon, description) VALUES
        (1, 'Emergency Backup', 'police', 'Request immediate police assistance.'),
        (2, 'Medical Emergency', 'medical', 'Request an ambulance.'),
        (3, 'Tow Truck', 'tow-truck', 'Request a tow truck for your vehicle.'),
        (4, 'Taxi Ride', 'taxi', 'Request a cab to your location.')
    ]])

    Companies.Reload()
    Requests.Reload()

    print("^2[Services+] Dummy test data seeded!^0")
end)
