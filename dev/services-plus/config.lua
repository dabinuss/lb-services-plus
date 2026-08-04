Config = Config or {}

Config.Framework = "auto" -- auto, esx, qbcore, qbox, standalone
Config.Locale = "en"
Config.Debug = false
Config.LogLevel = "info" -- debug, info, warning, error
Config.AppDefaultInstalled = true
Config.AppIcon = "https://cfx-nui-services-plus/web/icon.svg"
Config.RegistrationDelayMs = 750
Config.ServerCallbackTimeoutMs = 10000
Config.MaxActionPayloadBytes = 20000
Config.MaxCompanies = 100
Config.MaxQueueBroadcastEntries = 100
Config.RequireEquippedPhone = true
Config.AdminAce = "servicesplus.admin"
Config.ApiAllowedResources = {
    -- "your-mdt-resource"
}

-- Exact hosts and wildcard subdomains accepted for message attachments.
-- Replace these defaults with the hosts used by your configured LB Phone upload provider.
Config.AllowedMediaDomains = {
    "cdn.discordapp.com",
    "media.discordapp.net",
    "i.imgur.com",
    "*.fivemanage.com"
}

Config.RateLimitTelemetry = {
    enabled = true,
    summaryWindowMs = 60000,
    maxEntries = 50
}

Config.RateLimits = {
    getInitialState = { limit = 12, windowMs = 60000 },
    enterDuty = { limit = 5, windowMs = 30000 },
    leaveDuty = { limit = 5, windowMs = 30000 },
    updateStatus = { limit = 15, windowMs = 30000 },
    toggleDispatch = { limit = 10, windowMs = 30000 },
    updateCompanyOperations = { limit = 8, windowMs = 60000 },
    updateNumberOperations = { limit = 8, windowMs = 60000 },
    toggleDispatchLine = { limit = 20, windowMs = 60000 },
    externalCreateRequest = { limit = 6, windowMs = 60000 },
    externalRequestAction = { limit = 30, windowMs = 30000 },
    externalTransitionRequest = { limit = 20, windowMs = 30000 },
    externalSendCompanyMessage = { limit = 20, windowMs = 60000 },
    externalRead = { limit = 120, windowMs = 60000 },
    externalList = { limit = 30, windowMs = 60000 },
    externalWrite = { limit = 60, windowMs = 60000 },
    phoneChanged = { limit = 6, windowMs = 10000 },
    startCompanyCall = { limit = 8, windowMs = 30000 },
    getEmployeeContact = { limit = 10, windowMs = 30000 },
    registerIncomingCall = { limit = 20, windowMs = 30000 },
    acceptCall = { limit = 8, windowMs = 30000 },
    declineCall = { limit = 12, windowMs = 30000 },
    endCustomCall = { limit = 12, windowMs = 30000 },
    createRequest = { limit = 4, windowMs = 60000 },
    getRequestOptions = { limit = 15, windowMs = 60000 },
    getCompanyWorkspace = { limit = 15, windowMs = 60000 },
    acceptRequest = { limit = 8, windowMs = 30000 },
    declineRequest = { limit = 12, windowMs = 30000 },
    transitionRequest = { limit = 15, windowMs = 30000 },
    returnRequest = { limit = 8, windowMs = 30000 },
    cancelRequest = { limit = 6, windowMs = 60000 },
    updateRequestSettings = { limit = 6, windowMs = 60000 },
    sendCitizenMessage = { limit = 12, windowMs = 60000 },
    sendEmployeeMessage = { limit = 20, windowMs = 60000 },
    getCitizenInbox = { limit = 15, windowMs = 60000 },
    getConversationMessages = { limit = 20, windowMs = 60000 },
    reactToMessage = { limit = 30, windowMs = 60000 },
    getMyActivity = { limit = 12, windowMs = 60000 },
    getAdminState = { limit = 8, windowMs = 60000 },
    adminSaveCompany = { limit = 10, windowMs = 60000 },
    adminDeleteCompany = { limit = 5, windowMs = 60000 },
    adminRestoreCompany = { limit = 5, windowMs = 60000 },
    adminUpdateSettings = { limit = 8, windowMs = 60000 },
    adminUpdateCategory = { limit = 12, windowMs = 60000 },
    deleteRequest = { limit = 10, windowMs = 60000 },
    deleteConversation = { limit = 10, windowMs = 60000 },
    deleteMessage = { limit = 20, windowMs = 60000 }
}

Config.OptionalIntegrations = {
    notifications = { enabled = false, resource = "" },
    dispatch = { enabled = false, resource = "" },
    billing = { enabled = false, resource = "" },
    inventory = { enabled = false, resource = "" },
    map = { enabled = false, resource = "" }
}

Config.LeaderGrades = {
    police = 4,
    ambulance = 4,
    taxi = 3,
    mechanic = 3,
    burgershot = 3
}

Config.ExplicitLeaders = {}

Config.StandalonePlayers = {
    -- ["license:example"] = { job = "taxi", grade = 3, role = "Manager", name = "Alex Morgan" }
}

Config.Companies = {
    {
        id = "lspd",
        job = "police",
        displayName = "Los Santos Police Department",
        logo = "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=256&q=80",
        backgroundImage = "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=900&q=80",
        dispatchMode = "ring_all",
        categoryId = "police_justice",
        description = "Public safety and non-emergency police services.",
        location = "Mission Row",
        openingHours = "24/7",
        keywords = { "police", "law", "report", "justice" },
        requestsEnabled = false,
        messagesEnabled = true,
        numbers = {
            { id = "lspd-main", label = "Main Line", number = "911", distribution = "ring_all", sharedInbox = true }
        }
    },
    {
        id = "pillbox",
        job = "ambulance",
        displayName = "Pillbox Medical Center",
        logo = "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=256&q=80",
        backgroundImage = "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=900&q=80",
        dispatchMode = "ring_all",
        categoryId = "emergency_medical",
        description = "Emergency care and medical assistance.",
        location = "Pillbox Hill",
        openingHours = "24/7",
        keywords = { "hospital", "doctor", "ems", "medical" },
        requestsEnabled = false,
        messagesEnabled = true,
        numbers = {
            { id = "pillbox-main", label = "Emergency", number = "912", distribution = "ring_all", sharedInbox = true }
        }
    },
    {
        id = "downtown-cab",
        job = "taxi",
        displayName = "Downtown Cab Co.",
        logo = "https://images.unsplash.com/photo-1515569067071-ec3b51335dd0?auto=format&fit=crop&w=256&q=80",
        backgroundImage = "https://images.unsplash.com/photo-1515569067071-ec3b51335dd0?auto=format&fit=crop&w=900&q=80",
        dispatchMode = "dispatch_only",
        categoryId = "taxi_transport",
        description = "Reliable rides across Los Santos.",
        location = "East Vinewood",
        openingHours = "06:00 - 02:00",
        keywords = { "taxi", "cab", "ride", "transport" },
        requestsEnabled = true,
        messagesEnabled = true,
        numbers = {
            { id = "taxi-main", label = "Dispatch", number = "5550100", distribution = "dispatch_only", sharedInbox = true },
            { id = "taxi-booking", label = "Bookings", number = "5550101", distribution = "random", sharedInbox = true }
        }
    },
    {
        id = "bennys",
        job = "mechanic",
        displayName = "Benny's Motorworks",
        logo = "https://images.unsplash.com/photo-1487754180451-c456f719a1fc?auto=format&fit=crop&w=256&q=80",
        backgroundImage = "https://images.unsplash.com/photo-1487754180451-c456f719a1fc?auto=format&fit=crop&w=900&q=80",
        dispatchMode = "ring_all",
        categoryId = "vehicle_services",
        description = "Repairs, tuning and roadside assistance.",
        location = "Strawberry",
        openingHours = "10:00 - 23:00",
        keywords = { "mechanic", "repair", "tuning", "tow" },
        requestsEnabled = true,
        messagesEnabled = true,
        numbers = {
            { id = "bennys-main", label = "Workshop", number = "5550200", distribution = "ring_all", sharedInbox = true }
        }
    },
    {
        id = "burgershot",
        job = "burgershot",
        displayName = "Burger Shot",
        logo = "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=256&q=80",
        backgroundImage = "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=900&q=80",
        dispatchMode = "random",
        categoryId = "restaurants_food",
        description = "Fresh meals, collection and delivery.",
        location = "Vespucci Boulevard",
        openingHours = "11:00 - 01:00",
        keywords = { "food", "burger", "restaurant", "delivery" },
        requestsEnabled = true,
        messagesEnabled = true,
        numbers = {
            { id = "burgershot-orders", label = "Orders", number = "5550300", distribution = "random", sharedInbox = true }
        }
    }
}
