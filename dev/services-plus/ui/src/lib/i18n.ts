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
    noCompanyHint: "Your current framework job is not linked to a Services+ company.", yourStatus: "Your status", onBreak: "On break", occupied: "Busy", occupiedHint: "Do not receive calls or requests",
    dispatch: "Dispatch", requiredAlone: "Required while alone", receiveDispatch: "Receive dispatch calls", activeTeam: "Active team",
    leaveDuty: "Leave duty", leaderSettings: "Leader settings", operations: "Company operations", messages: "Messages",
    save: "Save changes", language: "Language", system: "General settings", companyManagement: "Companies", addCompany: "Add company",
    saveCompany: "Save company", deleteCompany: "Delete company", globalCalls: "Enable all calls", globalRequests: "Enable all requests",
    directoryTitle: "Directory title", name: "Name", category: "Category", job: "Framework job", logo: "Logo URL", backgroundImage: "Card background URL",
    description: "Description", openingHours: "Opening hours", keywords: "Keywords", phoneNumbers: "Phone numbers", addNumber: "Add number", numberLabel: "Display name", phoneNumber: "Phone number", callDistribution: "Call distribution", numberCapabilities: "Available functions",
    deletedCompanies: "Deleted companies", restoreCompany: "Restore company", deletedOn: "Deleted on",
    queueDuration: "Queue time", callDuration: "Call duration",
    dispatchMode: "Dispatch handling", ringAll: "Ring all", random: "Random", dispatchOnly: "Dispatch only", currentDispatch: "Current dispatch",
    noDispatch: "No dispatcher selected", role: "Role", contactEmployee: "Open employee contact", callEmployee: "Call employee", numberInbox: "Number-specific inbox/request box",
    newMessage: "New message", message: "Message", send: "Send", sent: "Sent", inbox: "Shared inbox", media: "Media", chooseMedia: "Choose media", removeAttachment: "Remove media", emojis: "Emojis", reactions: "Reactions", react: "React",
    noMessages: "No conversations yet", messageSent: "Message sent", operationFailed: "The action could not be completed. Please try again.", conversationLoadFailed: "Messages could not be loaded.", retry: "Try again", requestCreated: "Request created", requestCreationFailed: "The request could not be sent. Please call the company instead.", incomingCall: "Incoming call", incomingRequest: "Incoming request", teamSearch: "Search team", noTeamMembers: "No team members found", pagination: "List pages", previousPage: "Previous page", nextPage: "Next page",
    newRequest: "New request", accept: "Accept", decline: "Decline", companyCalls: "Company calls", configure: "Configure", waiting: "Waiting", assignedTo: "Handled by", assignedEmployee: "Employee", returnRequest: "Return request", generalRequests: "General requests", specialRequests: "Special requests", noSpecialRequests: "No specialized requests for this category", selectOption: "Select an option",
    unknownCaller: "Unknown caller", requestLabel: "Request label", createLabel: "Creation label", templates: "Templates", back: "Back", queuePosition: "Queue position", selectNumber: "Select phone number", sendLocation: "Send current location", locationSent: "Location sent", enabled: "Enabled", required: "Required", categoryCompetition: "Cross-company request competition", categoryCompetitionHint: "Available employees in this category compete for requests", deleteRequest: "Delete request", deleteConversation: "Delete conversation", deleteMessage: "Delete message", public: "Citizen directory", numberCapabilitiesHint: "Enabled is the master switch. Calls, inbox and requests enable those channels for this number. Citizen directory makes the enabled channels available to citizens; disabling it does not remove the internal inbox.", staffedLines: "Staffed lines", navigation: "Navigation on acceptance", navigationDisabled: "Disabled", navigationAsk: "Ask employee", navigationAutomatic: "Automatic", activeRequests: "Active requests", requestHistory: "Request history", allInboxes: "All inboxes"
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
    noCompanyHint: "Dein aktueller Framework-Job ist keinem Services+-Unternehmen zugeordnet.", yourStatus: "Dein Status", onBreak: "Pause", occupied: "Beschäftigt", occupiedHint: "Keine Anrufe oder Anfragen empfangen",
    dispatch: "Leitstelle", requiredAlone: "Erforderlich, solange du allein bist", receiveDispatch: "Leitstellenanrufe empfangen", activeTeam: "Aktives Team",
    leaveDuty: "Dienst beenden", leaderSettings: "Leitungseinstellungen", operations: "Unternehmensbetrieb", messages: "Nachrichten",
    save: "Änderungen speichern", language: "Sprache", system: "Allgemeine Einstellungen", companyManagement: "Unternehmen", addCompany: "Unternehmen hinzufügen",
    saveCompany: "Unternehmen speichern", deleteCompany: "Unternehmen löschen", globalCalls: "Alle Anrufe aktivieren", globalRequests: "Alle Anfragen aktivieren",
    directoryTitle: "Titel des Verzeichnisses", name: "Name", category: "Kategorie", job: "Framework-Job", logo: "Logo-URL", backgroundImage: "URL des Kartenhintergrunds",
    description: "Beschreibung", openingHours: "Öffnungszeiten", keywords: "Suchbegriffe", phoneNumbers: "Telefonnummern", addNumber: "Nummer hinzufügen", numberLabel: "Bezeichnung", phoneNumber: "Telefonnummer", callDistribution: "Anrufverteilung", numberCapabilities: "Verfügbare Funktionen",
    deletedCompanies: "Gelöschte Unternehmen", restoreCompany: "Unternehmen wiederherstellen", deletedOn: "Gelöscht am",
    queueDuration: "Wartezeit", callDuration: "Gesprächsdauer",
    dispatchMode: "Leitstellenverteilung", ringAll: "Alle klingeln", random: "Zufällig", dispatchOnly: "Nur Leitstelle", currentDispatch: "Aktuelle Leitstelle",
    noDispatch: "Keine Leitstelle ausgewählt", role: "Position", contactEmployee: "Mitarbeiterkontakt öffnen", callEmployee: "Mitarbeiter anrufen", numberInbox: "Nummer-eigenes Postfach/Requestbox",
    newMessage: "Neue Nachricht", message: "Nachricht", send: "Senden", sent: "Gesendet", inbox: "Gemeinsames Postfach", media: "Medien", chooseMedia: "Medien auswählen", removeAttachment: "Medium entfernen", emojis: "Emojis", reactions: "Reaktionen", react: "Reagieren",
    noMessages: "Noch keine Gespräche", messageSent: "Nachricht gesendet", operationFailed: "Die Aktion konnte nicht abgeschlossen werden. Bitte versuche es erneut.", conversationLoadFailed: "Nachrichten konnten nicht geladen werden.", retry: "Erneut versuchen", requestCreated: "Anfrage erstellt", requestCreationFailed: "Die Anfrage konnte nicht gesendet werden. Bitte rufe das Unternehmen stattdessen an.", incomingCall: "Eingehender Anruf", incomingRequest: "Eingehende Anfrage", teamSearch: "Team durchsuchen", noTeamMembers: "Keine Teammitglieder gefunden", pagination: "Listenseiten", previousPage: "Vorherige Seite", nextPage: "Nächste Seite",
    newRequest: "Neue Anfrage", accept: "Annehmen", decline: "Ablehnen", companyCalls: "Unternehmensanrufe", configure: "Konfigurieren", waiting: "Wartet", assignedTo: "Übernommen von", assignedEmployee: "Mitarbeiter", returnRequest: "Anfrage zurückgeben", generalRequests: "Allgemeine Anfragen", specialRequests: "Spezielle Anfragen", noSpecialRequests: "Keine speziellen Requests für diese Kategorie", selectOption: "Bitte auswählen",
    unknownCaller: "Unbekannter Anrufer", requestLabel: "Anfragebezeichnung", createLabel: "Aktionsbezeichnung", templates: "Vorlagen", back: "Zurück", queuePosition: "Warteschlangenposition", selectNumber: "Telefonnummer auswählen", sendLocation: "Aktuellen Standort senden", locationSent: "Standort gesendet", enabled: "Aktiv", required: "Pflichtfeld", categoryCompetition: "Unternehmensübergreifender Request-Wettbewerb", categoryCompetitionHint: "Verfügbare Mitarbeiter dieser Kategorie konkurrieren um Requests", deleteRequest: "Anfrage löschen", deleteConversation: "Gespräch löschen", deleteMessage: "Nachricht löschen", public: "Im Bürgerverzeichnis", numberCapabilitiesHint: "Aktiv ist der Hauptschalter. Anrufe, Postfach und Anfragen aktivieren den jeweiligen Kanal dieser Nummer. Im Bürgerverzeichnis stellt die aktivierten Kanäle Bürgern bereit; das Abschalten entfernt das interne Postfach nicht.", staffedLines: "Besetzte Leitungen", navigation: "Navigation bei Annahme", navigationDisabled: "Deaktiviert", navigationAsk: "Mitarbeiter fragen", navigationAutomatic: "Automatisch", activeRequests: "Aktive Anfragen", requestHistory: "Anfrageverlauf", allInboxes: "Alle Postfächer"
  }
} as const;

export type MessageKey = keyof typeof messages.en;
export function t(locale: Locale, key: MessageKey) { return messages[locale][key] ?? messages.en[key]; }
