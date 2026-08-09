ServicesPlus.RequestDefinitions = {
    fields = {
        description = { type = "description", label = { en = "Description", de = "Beschreibung" }, maxLength = 1000 },
        location = { type = "location", label = { en = "Location", de = "Standort" }, maxLength = 150 },
        phone = { type = "phone", label = { en = "Phone number", de = "Telefonnummer" }, maxLength = 32 },
        requested_time = { type = "requested_time", label = { en = "Requested time", de = "Gewünschte Zeit" }, maxLength = 40 },
        people = { type = "people", label = { en = "Number of people", de = "Anzahl Personen" }, minimum = 1, maximum = 20 },
        image = { type = "image", label = { en = "Image URL", de = "Bild-URL" }, maxLength = 500 },
        notes = { type = "notes", label = { en = "Additional notes", de = "Zusätzliche Hinweise" }, maxLength = 500 },
        legal_area = { type = "select", label = { en = "Area of law", de = "Rechtsgebiet" }, options = {
            { value = "criminal_law", label = { en = "Criminal law", de = "Strafrecht" } },
            { value = "civil_law", label = { en = "Civil law", de = "Zivilrecht" } },
            { value = "other", label = { en = "Other", de = "Sonstiges" } }
        } },
        urgency = { type = "select", label = { en = "Urgency", de = "Dringlichkeit" }, options = {
            { value = "normal", label = { en = "Normal", de = "Normal" } },
            { value = "urgent", label = { en = "Urgent", de = "Dringend" } },
            { value = "immediate", label = { en = "Immediate", de = "Sofort" } }
        } },
        vehicle_category = { type = "select", label = { en = "Vehicle type", de = "Fahrzeugtyp" }, options = {
            { value = "car", label = { en = "Car", de = "Auto" } },
            { value = "truck", label = { en = "Truck", de = "LKW" } },
            { value = "motorcycle", label = { en = "Motorcycle", de = "Motorrad" } }
        } },
        tip_category = { type = "select", label = { en = "Tip type", de = "Art des Hinweises" }, options = {
            { value = "breaking_news", label = { en = "Breaking news", de = "Eilmeldung" } },
            { value = "celebrity_sighting", label = { en = "Celebrity sighting", de = "Promi-Sichtung" } },
            { value = "other", label = { en = "Other", de = "Sonstiges" } }
        } },
        tip_details = { type = "description", label = { en = "Details (what or who)", de = "Details (was oder wer)" }, maxLength = 1000 }
    },
    templates = {
        -- Emergency dispatch: one free-text field plus the citizen's real position, captured
        -- automatically server-side - no manual location entry, matching the taxi pickup flow.
        emergency_dispatch = { kind = "specialized", categoryIds = { "government" }, name = { en = "Emergency Dispatch", de = "Notfall" }, fields = { { id = "description", required = true } } },
        ems_dispatch = { kind = "specialized", categoryIds = { "emergency_medical" }, name = { en = "Emergency Dispatch", de = "Notfall" }, fields = { { id = "description", required = true } } },
        immediate_pickup = { kind = "specialized", categoryIds = { "taxi_transport" }, name = { en = "Pickup", de = "Abholung" }, fields = { { id = "people", required = true } } },
        towing = { kind = "specialized", categoryIds = { "vehicle_services" }, name = { en = "Towing Request", de = "Abschleppauftrag" }, fields = { { id = "vehicle_category", required = true } } },
        news_tip = { kind = "specialized", categoryIds = { "news_media" }, name = { en = "News Tip", de = "Hinweis" }, fields = { { id = "tip_category", required = true }, { id = "tip_details", required = true } } },
        -- General-purpose delivery, usable by any category that ships physical goods.
        delivery = { kind = "specialized", categoryIds = { "restaurants", "delivery_services" }, name = { en = "Delivery", de = "Lieferung" }, fields = { { id = "description", required = true }, { id = "location", required = true }, { id = "phone", required = false } } },
        reservation = { kind = "specialized", categoryIds = { "restaurants" }, name = { en = "Table reservation", de = "Tischreservierung" }, fields = { { id = "requested_time", required = true }, { id = "people", required = true }, { id = "phone", required = false }, { id = "notes", required = false } } },
        property_viewing = { kind = "specialized", categoryIds = { "real_estate" }, name = { en = "Property viewing", de = "Immobilienbesichtigung" }, fields = { { id = "location", required = true }, { id = "description", required = true }, { id = "phone", required = false } } },
        legal_assistance = { kind = "specialized", categoryIds = { "legal_services" }, name = { en = "Legal assistance", de = "Anwalt anfragen" }, fields = { { id = "legal_area", required = true }, { id = "urgency", required = true }, { id = "phone", required = false } } }
    },
    categoryTemplates = {
        government = { "emergency_dispatch" },
        legal_services = { "legal_assistance" },
        emergency_medical = { "ems_dispatch" },
        taxi_transport = { "immediate_pickup" },
        vehicle_services = { "towing" },
        restaurants = { "reservation", "delivery" },
        delivery_services = { "delivery" },
        news_media = { "news_tip" },
        real_estate = { "property_viewing" }
        -- community: no request template.
    }
}
