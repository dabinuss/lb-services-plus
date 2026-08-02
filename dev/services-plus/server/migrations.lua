ServicesPlus.Migrations = ServicesPlus.Migrations or {}

local Migrations = ServicesPlus.Migrations

function Migrations.Validate()
    local ok, version = pcall(function()
        return MySQL.scalar.await("SELECT MAX(`version`) FROM `services_plus_schema_migrations`")
    end)

    if not ok then
        return false, "Database schema is missing. Apply sql/install.sql before starting Services+."
    end
    if (tonumber(version) or 0) < 7 then
        return false, "Database schema is outdated. Apply migrations through sql/migrations/007_phase2_number_staffing_notifications_navigation_api.sql."
    end
    return true
end
