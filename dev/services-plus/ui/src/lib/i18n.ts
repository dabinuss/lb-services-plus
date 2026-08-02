export type Locale = "en" | "de";

const messages = {
  en: {
    directory: "Directory", activity: "My activity", portal: "Company portal", admin: "Administration",
    search: "Search companies or categories...", all: "All categories", services: "services", noServices: "No services found",
    noServicesHint: "Try another company, category or service.", available: "Available", unavailable: "Unavailable",
    onDuty: "on duty", call: "Call", request: "Create request", locationMissing: "Location not listed", hoursMissing: "Hours not listed",
    requestTitle: "New request", details: "What do you need?", location: "Location", sendRequest: "Send request", cancel: "Cancel",
    calls: "Calls", requests: "Requests", noCalls: "No company calls yet", noRequests: "No requests yet", pending: "Pending",
    employeeAccess: "Employee access", signedIn: "Signed in as", enterDuty: "Enter duty", identifying: "Identifying employee...",
    checking: "Checking company access...", connecting: "Connecting to company services...", noCompany: "No company access",
    noCompanyHint: "Your current framework job is not linked to a Services+ company.", yourStatus: "Your status", onBreak: "On break",
    dispatch: "Dispatch", requiredAlone: "Required while alone", receiveDispatch: "Receive dispatch calls", activeTeam: "Active team",
    leaveDuty: "Leave duty", leaderSettings: "Leader settings", operations: "Company operations", messages: "Messages",
    save: "Save changes", language: "Language", system: "General settings", companyManagement: "Companies", addCompany: "Add company",
    saveCompany: "Save company", deleteCompany: "Delete company", globalCalls: "Enable all calls", globalRequests: "Enable all requests",
    directoryTitle: "Directory title", name: "Name", category: "Category", job: "Framework job", logo: "Logo URL", backgroundImage: "Card background URL",
    description: "Description", openingHours: "Opening hours", keywords: "Keywords", phoneNumbers: "Phone numbers", addNumber: "Add number",
    dispatchMode: "Dispatch handling", ringAll: "Ring all", random: "Random", dispatchOnly: "Dispatch only", currentDispatch: "Current dispatch",
    noDispatch: "No dispatcher selected", role: "Role", contactEmployee: "Open employee contact", callEmployee: "Call employee", numberInbox: "Number-specific inbox/request box"
  },
  de: {
    directory: "Verzeichnis", activity: "Meine Aktivitäten", portal: "Unternehmensportal", admin: "Administration",
    search: "Unternehmen oder Kategorien suchen...", all: "Alle Kategorien", services: "Dienste", noServices: "Keine Dienste gefunden",
    noServicesHint: "Versuche ein anderes Unternehmen, eine Kategorie oder einen Dienst.", available: "Verfügbar", unavailable: "Nicht verfügbar",
    onDuty: "im Dienst", call: "Anrufen", request: "Anfrage erstellen", locationMissing: "Kein Standort", hoursMissing: "Keine Öffnungszeiten",
    requestTitle: "Neue Anfrage", details: "Was benötigst du?", location: "Standort", sendRequest: "Anfrage senden", cancel: "Abbrechen",
    calls: "Anrufe", requests: "Anfragen", noCalls: "Noch keine Unternehmensanrufe", noRequests: "Noch keine Anfragen", pending: "Offen",
    employeeAccess: "Mitarbeiterzugang", signedIn: "Angemeldet als", enterDuty: "Dienst beginnen", identifying: "Mitarbeiter wird identifiziert...",
    checking: "Unternehmenszugang wird geprüft...", connecting: "Verbindung wird hergestellt...", noCompany: "Kein Unternehmenszugang",
    noCompanyHint: "Dein aktueller Framework-Job ist keinem Services+-Unternehmen zugeordnet.", yourStatus: "Dein Status", onBreak: "Pause",
    dispatch: "Leitstelle", requiredAlone: "Erforderlich, solange du allein bist", receiveDispatch: "Leitstellenanrufe empfangen", activeTeam: "Aktives Team",
    leaveDuty: "Dienst beenden", leaderSettings: "Leitungseinstellungen", operations: "Unternehmensbetrieb", messages: "Nachrichten",
    save: "Änderungen speichern", language: "Sprache", system: "Allgemeine Einstellungen", companyManagement: "Unternehmen", addCompany: "Unternehmen hinzufügen",
    saveCompany: "Unternehmen speichern", deleteCompany: "Unternehmen löschen", globalCalls: "Alle Anrufe aktivieren", globalRequests: "Alle Anfragen aktivieren",
    directoryTitle: "Titel des Verzeichnisses", name: "Name", category: "Kategorie", job: "Framework-Job", logo: "Logo-URL", backgroundImage: "URL des Kartenhintergrunds",
    description: "Beschreibung", openingHours: "Öffnungszeiten", keywords: "Suchbegriffe", phoneNumbers: "Telefonnummern", addNumber: "Nummer hinzufügen",
    dispatchMode: "Leitstellenverteilung", ringAll: "Alle klingeln", random: "Zufällig", dispatchOnly: "Nur Leitstelle", currentDispatch: "Aktuelle Leitstelle",
    noDispatch: "Keine Leitstelle ausgewählt", role: "Position", contactEmployee: "Mitarbeiterkontakt öffnen", callEmployee: "Mitarbeiter anrufen", numberInbox: "Nummer-eigenes Postfach/Requestbox"
  }
} as const;

export type MessageKey = keyof typeof messages.en;
export function t(locale: Locale, key: MessageKey) { return messages[locale][key] ?? messages.en[key]; }
