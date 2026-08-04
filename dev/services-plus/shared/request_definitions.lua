ServicesPlus.RequestDefinitions = {
    fields = {
        description = { type = "description", label = { en = "Description", de = "Beschreibung" }, maxLength = 1000 },
        location = { type = "location", label = { en = "Location", de = "Standort" }, maxLength = 150 },
        phone = { type = "phone", label = { en = "Phone number", de = "Telefonnummer" }, maxLength = 32 },
        requested_time = { type = "requested_time", label = { en = "Requested time", de = "Gewünschte Zeit" }, maxLength = 40 },
        people = { type = "people", label = { en = "Number of people", de = "Anzahl Personen" }, minimum = 1, maximum = 20 },
        vehicle_plate = { type = "vehicle_plate", label = { en = "Vehicle plate", de = "Kennzeichen" }, maxLength = 16 },
        image = { type = "image", label = { en = "Image URL", de = "Bild-URL" }, maxLength = 500 },
        notes = { type = "notes", label = { en = "Additional notes", de = "Zusätzliche Hinweise" }, maxLength = 500 },
        injuries = { type = "notes", label = { en = "Injuries", de = "Verletzungen" }, maxLength = 700 },
        legal_area = { type = "select", label = { en = "Area of law", de = "Rechtsgebiet" }, options = {
            { value = "criminal_law", label = { en = "Criminal law", de = "Strafrecht" } },
            { value = "civil_law", label = { en = "Civil law", de = "Zivilrecht" } },
            { value = "other", label = { en = "Other", de = "Sonstiges" } }
        } },
        urgency = { type = "select", label = { en = "Urgency", de = "Dringlichkeit" }, options = {
            { value = "normal", label = { en = "Normal", de = "Normal" } },
            { value = "urgent", label = { en = "Urgent", de = "Dringend" } },
            { value = "immediate", label = { en = "Immediate", de = "Sofort" } }
        } }
    },
    templates = {
        immediate_pickup = { kind = "specialized", categoryIds = { "taxi_transport" }, name = { en = "Pickup", de = "Abholung" }, fields = { { id = "people", required = true }, { id = "phone", required = false } } },
        roadside_assistance = { kind = "specialized", categoryIds = { "vehicle_services" }, name = { en = "Roadside or towing assistance", de = "Pannen- oder Abschlepphilfe" }, fields = { { id = "location", required = true }, { id = "description", required = true }, { id = "vehicle_plate", required = false }, { id = "phone", required = false } } },
        -- General-purpose delivery, usable by any category that ships physical goods, not restaurant-specific.
        delivery = { kind = "specialized", categoryIds = { "restaurants_food", "retail" }, name = { en = "Delivery", de = "Lieferung" }, fields = { { id = "description", required = true }, { id = "location", required = true }, { id = "phone", required = false } } },
        reservation = { kind = "specialized", categoryIds = { "restaurants_food" }, name = { en = "Table reservation", de = "Tischreservierung" }, fields = { { id = "requested_time", required = true }, { id = "people", required = true }, { id = "phone", required = false }, { id = "notes", required = false } } },
        medical_transport = { kind = "specialized", categoryIds = { "emergency_medical" }, name = { en = "Medical transport", de = "Krankentransport" }, fields = { { id = "location", required = true }, { id = "people", required = true }, { id = "injuries", required = true } } },
        property_viewing = { kind = "specialized", categoryIds = { "real_estate" }, name = { en = "Property viewing", de = "Immobilienbesichtigung" }, fields = { { id = "location", required = true }, { id = "description", required = true }, { id = "phone", required = false } } },
        legal_assistance = { kind = "specialized", categoryIds = { "police_justice" }, name = { en = "Legal assistance", de = "Anwalt anfragen" }, fields = { { id = "legal_area", required = true }, { id = "urgency", required = true }, { id = "phone", required = false } } },
        police_report = { kind = "specialized", categoryIds = { "police_justice" }, name = { en = "Police request", de = "Polizeiliche Anfrage" }, fields = { { id = "location", required = true }, { id = "description", required = true }, { id = "phone", required = false } } }
    },
    categoryTemplates = {
        taxi_transport = { "immediate_pickup" },
        vehicle_services = { "roadside_assistance" },
        restaurants_food = { "delivery", "reservation" },
        retail = { "delivery" },
        emergency_medical = { "medical_transport" },
        real_estate = { "property_viewing" },
        police_justice = { "police_report", "legal_assistance" }
    },
    phases = {
        taxi_transport = {
            { id = "accepted", name = { en = "Accepted", de = "Angenommen" } },
            { id = "on_the_way", name = { en = "On the way", de = "Unterwegs" } },
            { id = "picked_up", name = { en = "Passenger picked up", de = "Fahrgast aufgenommen" } },
            { id = "ride_active", name = { en = "Ride active", de = "Fahrt aktiv" } },
            { id = "completed", name = { en = "Completed", de = "Abgeschlossen" } }
        },
        vehicle_services = {
            { id = "accepted", name = { en = "Accepted", de = "Angenommen" } },
            { id = "on_the_way", name = { en = "On the way", de = "Unterwegs" } },
            { id = "in_service", name = { en = "Vehicle in service", de = "Fahrzeug in Arbeit" } },
            { id = "completed", name = { en = "Completed", de = "Abgeschlossen" } }
        },
        restaurants_food = {
            { id = "accepted", name = { en = "Accepted", de = "Angenommen" } },
            { id = "preparing", name = { en = "In preparation", de = "In Zubereitung" } },
            { id = "ready", name = { en = "Ready", de = "Bereit" } },
            { id = "delivered", name = { en = "Delivered", de = "Ausgeliefert" } },
            { id = "completed", name = { en = "Completed", de = "Abgeschlossen" } }
        },
        other = {
            { id = "accepted", name = { en = "Accepted", de = "Angenommen" } },
            { id = "in_progress", name = { en = "In progress", de = "In Bearbeitung" } },
            { id = "completed", name = { en = "Completed", de = "Abgeschlossen" } }
        }
    }
}
