# FiveM LB-Phone App Development Guidelines

**Version:** 1.0  
**Stand:** 2. August 2026  
**Geltungsbereich:** Alle eigenen Apps, Erweiterungen und Integrationen für LB Phone auf FiveM

---

## 1. Ziel dieses Dokuments

Dieses Dokument definiert die grundlegenden technischen, qualitativen und organisatorischen Anforderungen für die Entwicklung eigener FiveM-Apps für LB Phone.

Die wichtigsten Entwicklungsziele sind:

1. Höchstmögliche Performance
2. Hohe Server- und Client-Stabilität
3. Möglichst geringer Netzwerk- und Datenbankverkehr
4. Flüssige und reaktionsschnelle Benutzeroberflächen
5. Sichere, serverautorisierte Geschäftslogik
6. Gut strukturierter und langfristig wartbarer Code
7. Regelmäßige Codeüberprüfung während der gesamten Entwicklung
8. Vollständige englische Code-Dokumentation

Eine App gilt nicht allein dann als fertig, wenn ihre Funktionen sichtbar arbeiten. Sie gilt erst dann als fertig, wenn sie auch unter hoher Last, bei langsamen Verbindungen, bei Resource-Restarts und bei unerwarteten Eingaben stabil funktioniert.

---

## 2. Verbindliche offizielle Dokumentation

Bei technischen Entscheidungen sind zuerst die offiziellen Dokumentationen zu prüfen.

### 2.1 LB Phone

Allgemeine LB-Phone-Dokumentation:

https://docs.lbscripts.com/phone/

Custom Apps:

https://docs.lbscripts.com/phone/custom-apps/

Client Exports:

https://docs.lbscripts.com/phone/exports/client-exports/

Installation und Abhängigkeiten:

https://docs.lbscripts.com/phone/installation/

Offizielle App-Templates:

https://github.com/lbphone/lb-phone-app-template

Die offizielle Vorlage enthält Varianten für React mit JavaScript, React mit TypeScript, Vanilla JavaScript und Vue. Für größere oder längerfristig gepflegte Projekte wird grundsätzlich React mit TypeScript bevorzugt.

### 2.2 FiveM und Cfx.re

FiveM-Dokumentation:

https://docs.fivem.net/docs/

Resource Manifest:

https://docs.fivem.net/docs/scripting-reference/resource-manifest/

NUI-Entwicklung:

https://docs.fivem.net/docs/scripting-manual/nui-development/

NUI Callbacks:

https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/

Events:

https://docs.fivem.net/docs/scripting-manual/working-with-events/

Event Security:

https://docs.fivem.net/docs/developers/server-security/

Übertragung größerer Datenmengen:

https://docs.fivem.net/docs/scripting-manual/working-with-events/triggering-events/

FiveM Profiler:

https://docs.fivem.net/docs/scripting-manual/debugging/using-profiler/

JavaScript- und TypeScript-Runtime:

https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/

Resource Monitor und allgemeine Performance-Hinweise:

https://docs.fivem.net/docs/scripting-manual/introduction/fact-sheet/

---

## 3. Grundlegende Projektarchitektur

Eine LB-Phone-App soll als eigene FiveM-Resource entwickelt werden. Änderungen direkt innerhalb der LB-Phone-Resource sind nach Möglichkeit zu vermeiden.

LB Phone empfiehlt für Apps mit eigener Benutzeroberfläche eine separate Resource, die über die offiziellen Exports registriert wird. Die Custom-App-Resource muss nach `lb-phone` gestartet werden.

### 3.1 Empfohlene Aufteilung

```text
my-phone-app/
├── fxmanifest.lua
├── README.md
├── CHANGELOG.md
├── client/
│   ├── main.lua
│   ├── callbacks.lua
│   ├── events.lua
│   └── app.lua
├── server/
│   ├── main.lua
│   ├── callbacks.lua
│   ├── events.lua
│   ├── services/
│   └── repositories/
├── shared/
│   ├── config.lua
│   ├── constants.lua
│   └── types.lua
├── locales/
│   ├── en.json
│   └── de.json
├── ui/
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── tsconfig.json
│   └── vite.config.ts
└── web/
    └── build-output
```

### 3.2 Verantwortlichkeiten

#### Frontend

Das Frontend ist ausschließlich für folgende Aufgaben zuständig:

- Darstellung der Benutzeroberfläche
- Lokaler UI-Zustand
- Animationen und Übergänge
- Formulareingaben
- Optimistische Darstellung
- Anfrage von Daten über NUI
- Verarbeitung von Push-Updates

Das Frontend darf keine sicherheitsrelevanten Entscheidungen treffen.

#### FiveM-Client

Der Client bildet die Brücke zwischen LB Phone, NUI und FiveM.

Er ist zuständig für:

- Registrierung der App
- NUI Callbacks
- LB-Phone-Client-Exports
- Lokale FiveM-Funktionen
- Weiterleitung berechtigter Anfragen an den Server
- Empfang gezielter Server-Updates
- Ressourcen- und UI-Lifecycle

#### FiveM-Server

Der Server ist die autoritative Instanz.

Er ist zuständig für:

- Authentifizierung
- Berechtigungsprüfung
- Rollenprüfung
- Besitzverhältnisse
- Geschäftslogik
- Datenbankzugriffe
- Validierung
- Rate Limits
- Manipulationsschutz
- Persistenz
- Verteilung von Änderungen an berechtigte Clients

#### Datenbank

Die Datenbank ist die dauerhafte Quelle für persistente Daten.

Clientdaten, lokale Caches und Frontendzustände dürfen niemals als verlässliche Quelle für Eigentum, Rollen, Kontostände, Berechtigungen oder abgeschlossene Aktionen verwendet werden.

---

## 4. Resource Manifest

Jede Resource benötigt ein `fxmanifest.lua`. Das Manifest definiert Metadaten, Dateien, Scripts, Abhängigkeiten und die NUI-Seite.

Beispiel:

```lua
fx_version "cerulean"
game "gta5"

author "Project Name"
description "Custom LB Phone application"
version "1.0.0"

lua54 "yes"

ui_page "web/index.html"

files {
    "web/index.html",
    "web/**/*"
}

shared_scripts {
    "shared/config.lua",
    "shared/constants.lua"
}

client_scripts {
    "client/app.lua",
    "client/callbacks.lua",
    "client/events.lua",
    "client/main.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/repositories/*.lua",
    "server/services/*.lua",
    "server/callbacks.lua",
    "server/events.lua",
    "server/main.lua"
}

dependency "lb-phone"
```

Die tatsächlich benötigten Dateien sollen explizit eingebunden werden. Unnötige Dateien, Source Maps, Entwicklungsdateien, Screenshots oder große nicht verwendete Assets gehören nicht in die ausgelieferte Resource.

---

## 5. LB-Phone-App-Registrierung

Eigene Apps sollen über den offiziellen Export `AddCustomApp` registriert werden.

Nach dem Start von `lb-phone` sollte kurz gewartet werden, damit der Export sicher verfügbar ist.

Beispiel:

```lua
local APP_IDENTIFIER = "my-phone-app"

local function registerApp()
    local success, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = APP_IDENTIFIER,
        name = "My App",
        description = "Application description",
        developer = "Developer Name",
        defaultApp = true,
        ui = "web/index.html",
        icon = "https://cfx-nui-my-phone-app/web/icon.png",
        fixBlur = true,

        onOpen = function()
            -- Do not send initial application data here.
        end,

        onClose = function()
            -- Release temporary client state when appropriate.
        end
    })

    if not success then
        print(("[my-phone-app] Failed to register app: %s"):format(
            errorMessage or "unknown error"
        ))
    end
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName()
        and resourceName ~= "lb-phone" then
        return
    end

    SetTimeout(500, registerApp)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports["lb-phone"]:RemoveCustomApp(APP_IDENTIFIER)
end)
```

Die Rückgabewerte offizieller Exports sind immer auszuwerten. Fehler dürfen nicht still ignoriert werden.

---

## 6. Initialer Datenabruf

Initiale App-Daten dürfen nicht unkontrolliert über `onOpen` an das Frontend gesendet werden.

Der App-Iframe ist zu diesem Zeitpunkt möglicherweise noch nicht vollständig geladen. Nachrichten können dadurch verloren gehen. Stattdessen soll das Frontend nach dem Mounten selbst die initialen Daten über `fetchNui` anfordern.

Spätere Updates werden über `SendCustomAppMessage` übertragen.

### 6.1 Client Callback

```lua
RegisterNUICallback("getInitialState", function(_, callback)
    local state = {
        success = true,
        data = {
            currentUser = {},
            settings = {},
            items = {}
        }
    }

    callback(state)
end)
```

### 6.2 Frontend

```ts
interface InitialState {
    currentUser: User;
    settings: AppSettings;
    items: AppItem[];
}

interface ApiResponse<T> {
    success: boolean;
    data?: T;
    error?: {
        code: string;
        message: string;
    };
}

const response = await fetchNui<ApiResponse<InitialState>>(
    "getInitialState"
);
```

Jeder NUI Callback muss den Callback immer aufrufen. Unterbleibt die Antwort, läuft die Anfrage in einen Timeout.

Die übertragenen Daten müssen JSON-kompatibel sein.

---

## 7. Kommunikation zwischen App und LB Phone

Für Nachrichten an eine Custom-App muss `SendCustomAppMessage` verwendet werden.

Client:

```lua
exports["lb-phone"]:SendCustomAppMessage("my-phone-app", {
    action = "itemUpdated",
    payload = {
        id = 42,
        status = "completed"
    }
})
```

Frontend:

```ts
onNuiEvent<ItemUpdatedPayload>("itemUpdated", (payload) => {
    updateItem(payload);
});
```

### 7.1 Nachrichtenformat

Alle Nachrichten sollen ein einheitliches Format besitzen:

```ts
interface AppMessage<T> {
    type: string;
    requestId?: string;
    version?: number;
    timestamp?: number;
    payload: T;
}
```

Empfohlene Regeln:

- `type` beschreibt das Ereignis.
- `requestId` verbindet Anfrage und Antwort.
- `version` schützt vor veralteten Updates.
- `timestamp` dient nur der Diagnose und Darstellung.
- `payload` enthält ausschließlich benötigte Daten.
- Keine vollständigen Datenbestände senden, wenn ein Delta ausreicht.
- Keine sensiblen Serverinformationen übertragen.

---

## 8. Netzwerk- und Datenverkehr

Das Netzwerk ist als begrenzte Ressource zu behandeln.

### 8.1 Grundregeln

- Nur benötigte Felder übertragen.
- Keine vollständigen Datenobjekte senden, wenn sich nur ein Feld geändert hat.
- Keine regelmäßigen Komplett-Synchronisierungen.
- Keine permanenten Polling-Schleifen.
- Updates nur an betroffene Spieler senden.
- Globale Broadcasts mit Ziel `-1` nur bei tatsächlich globalen Informationen.
- Listen paginieren.
- Suchergebnisse begrenzen.
- Texte, Anhänge und Arrays mit festen Maximalgrößen versehen.
- Schreibvorgänge nach Möglichkeit bündeln.
- Tipp- und Suchanfragen debouncen.
- Doppelte Requests erkennen und verhindern.
- Bereits vorhandene Daten nicht wiederholt laden.

### 8.2 Kleine und große Events

Für kleine Transaktionen werden normale Network Events verwendet.

Bei größeren Datenmengen können Latent Events verwendet werden. Diese blockieren den Netzwerkkanal nicht auf dieselbe Weise wie normale Events.

Sehr große Payloads sollten trotzdem grundsätzlich vermieden werden.

```lua
TriggerLatentServerEvent(
    "my-phone-app:server:uploadData",
    25000,
    payload
)
```

Latent Events sind kein Ersatz für Pagination, Komprimierung oder vernünftige Datenmodelle.

### 8.3 Kein unnötiges Polling

Schlecht:

```ts
setInterval(loadAllMessages, 1000);
```

Besser:

1. Initiale Nachrichten einmalig laden.
2. Neue Nachrichten ereignisbasiert übertragen.
3. Nur bei erkannten Lücken eine gezielte Synchronisierung durchführen.
4. Beim erneuten Öffnen der App nur Änderungen seit der letzten bekannten Version laden.

---

## 9. Serverautorität und Sicherheit

Sämtliche Clientdaten sind als potenziell manipuliert zu betrachten.

Clients können Network Events eigenständig auslösen. Deshalb muss jeder serverseitige Event Handler eigene Prüfungen durchführen.

### 9.1 Serverseitig zu prüfen

Bei jeder Aktion sind abhängig vom Anwendungsfall mindestens folgende Werte zu prüfen:

- Existiert der Spieler?
- Besitzt der Spieler ein gültiges Telefon?
- Besitzt er die angegebene Telefonnummer?
- Ist er authentifiziert?
- Hat er die benötigte Rolle?
- Gehört ihm der Datensatz?
- Darf er auf das Unternehmen oder den Chat zugreifen?
- Ist die Aktion im aktuellen Status erlaubt?
- Entspricht der Wert einem erlaubten Enum?
- Liegt die Textlänge innerhalb des Limits?
- Ist die ID syntaktisch und fachlich gültig?
- Ist die Aktion durch ein Rate Limit erlaubt?
- Wurde dieselbe Aktion bereits verarbeitet?
- Ist das Ziel noch vorhanden?
- Besteht eine gültige serverseitige Beziehung zwischen Absender und Ziel?

### 9.2 Niemals vom Client übernehmen

Der Client darf nicht verbindlich bestimmen:

- Geldbeträge
- Rollen
- Berechtigungen
- Eigentümer
- Absenderidentität
- Telefonnummern
- Unternehmenszugehörigkeit
- Erstellungszeitpunkte
- Ablaufzeitpunkte
- Statusübergänge
- Preise
- Belohnungen
- Empfängerlisten
- Moderationsrechte

Diese Werte müssen serverseitig ermittelt oder bestätigt werden.

### 9.3 Lokale und vernetzte Events

`AddEventHandler` soll verwendet werden, wenn ein Event nur innerhalb desselben Kontexts benötigt wird.

`RegisterNetEvent` beziehungsweise `onNet` soll nur verwendet werden, wenn eine Kommunikation zwischen Client und Server tatsächlich erforderlich ist.

### 9.4 Rate Limits

Jede schreibende oder teure Aktion benötigt ein serverseitiges Rate Limit.

Beispiele:

- Nachrichten senden
- Chat erstellen
- Request erstellen
- Suchanfragen
- Medienaktionen
- Statuswechsel
- Benutzer einladen
- Berechtigungen ändern
- Profil bearbeiten

Rate Limits sollen pro Spieler, Aktion und gegebenenfalls Ziel gelten.

---

## 10. Datenbankregeln

### 10.1 Allgemeine Anforderungen

- Datenbankzugriffe ausschließlich serverseitig
- Parametrisierte Queries
- Keine dynamisch zusammengebauten SQL-Werte
- Geeignete Indizes
- Pagination mit stabiler Sortierung
- Transaktionen bei zusammengehörenden Änderungen
- Eindeutige Constraints für fachlich eindeutige Datensätze
- Fremdschlüssel oder konsistente manuelle Referenzprüfungen
- Zeitstempel serverseitig erzeugen
- Löschkonzept vor Entwicklungsbeginn definieren
- Migrationen versionieren
- Vor Migrationen Backups erstellen

### 10.2 Keine Queries in Schleifen

Schlecht:

```lua
for _, userId in ipairs(userIds) do
    MySQL.single.await(
        "SELECT * FROM users WHERE id = ?",
        { userId }
    )
end
```

Besser:

- Daten in einer gemeinsamen Query laden.
- Joins verwenden, wenn sinnvoll.
- IDs gesammelt übergeben.
- Ergebnisse serverseitig zuordnen.

### 10.3 Pagination

Große Listen dürfen nie unbegrenzt geladen werden.

Jede Listenabfrage benötigt:

- `limit`
- Cursor oder eindeutigen Offset
- stabile Sortierung
- optionalen Filter
- maximal erlaubtes Limit
- Information darüber, ob weitere Daten vorhanden sind

Cursor-basierte Pagination ist bei sich häufig ändernden Chats und Aktivitätslisten meist stabiler als reine Offset-Pagination.

### 10.4 Caching

Caching ist erlaubt, wenn klare Regeln bestehen:

- Cache besitzt eine definierte Lebensdauer.
- Cache wird bei Änderungen invalidiert.
- Persistente Daten bleiben in der Datenbank.
- Berechtigungen werden nicht dauerhaft ungeprüft aus einem alten Cache übernommen.
- Caches werden bei Resource-Restarts sauber neu aufgebaut.
- Spielerbezogene Caches werden bei `playerDropped` entfernt.

---

## 11. Frontend-Performance

FiveM NUI basiert auf Chromium Embedded Framework und erlaubt moderne Webtechnologien. Trotzdem läuft die Benutzeroberfläche parallel zum Spiel und muss entsprechend ressourcenschonend umgesetzt werden.

### 11.1 Verbindliche UI-Regeln

- React-Komponenten klein und eindeutig halten.
- Unnötige Re-Renders vermeiden.
- Lange Listen virtualisieren.
- Große Bilder vor der Anzeige skalieren.
- Animationen sparsam verwenden.
- Keine dauerhaft laufenden Animationen im Hintergrund.
- Event Listener beim Unmount entfernen.
- Timer und Observer beim Unmount beenden.
- Nicht sichtbare Medien pausieren.
- Große Module lazy laden.
- Abhängigkeiten nur bei echtem Nutzen installieren.
- Keine mehrfachen globalen Stores für dieselben Daten.
- Keine riesigen Komplettzustände bei kleinen Änderungen kopieren.
- Suchfelder debouncen.
- Benutzeraktionen sofort sichtbar bestätigen.
- Ladezustände gezielt und nicht als vollständige Bildschirmsperre darstellen.
- Fehlerzustände müssen verständlich und wiederholbar sein.

### 11.2 App-Lifecycle

Beim Öffnen:

1. Lokalen Zustand initialisieren.
2. Initialdaten einmalig abrufen.
3. Push Listener aktivieren.
4. Sichtbare Inhalte laden.

Beim Schließen:

1. Timer stoppen.
2. Listener entfernen.
3. Medien pausieren.
4. Temporäre Object URLs freigeben.
5. Kamera- oder Karteninstanzen zerstören.
6. Unnötigen lokalen Zustand zurücksetzen.

---

## 12. Flüssiges Benutzererlebnis

Hohe Sicherheit und Serverautorität dürfen nicht zu einer schwerfälligen Bedienung führen.

### 12.1 Optimistic UI

Für geeignete Aktionen darf die Oberfläche vorläufig aktualisiert werden.

Beispiel:

1. Nachricht lokal mit Status `sending` anzeigen.
2. Anfrage mit eindeutiger `requestId` senden.
3. Server verarbeitet und speichert die Nachricht.
4. Server bestätigt die endgültige Nachrichten-ID.
5. Lokaler Eintrag wird ersetzt.
6. Bei einem Fehler erhält er den Status `failed`.

Optimistic UI darf nicht für irreversible oder sicherheitskritische Aktionen verwendet werden, ohne dass ein sauberer Rollback möglich ist.

### 12.2 Zustandsversionen

Echtzeitdaten sollten eine Version oder Sequenznummer besitzen.

Dadurch kann die App erkennen:

- ob ein Update veraltet ist,
- ob Updates fehlen,
- ob eine vollständige Neusynchronisierung notwendig ist,
- ob ein doppeltes Event bereits verarbeitet wurde.

### 12.3 Fehlerbehandlung

Fehlerantworten sollen einem einheitlichen Schema folgen:

```ts
interface AppError {
    code: string;
    message: string;
    retryable: boolean;
    details?: Record<string, unknown>;
}
```

Interne SQL-, Stack- oder Serverfehler dürfen nicht direkt an den Spieler übertragen werden.

---

## 13. Englischer Code und englische Dokumentation

Der gesamte eigene technische Code wird in englischer Sprache geschrieben.

Das umfasst:

- Variablennamen
- Funktionsnamen
- Klassen
- Interfaces
- Typen
- Eventnamen
- Datenbankspalten
- Kommentare
- Commit Messages
- Branch-Namen
- README-Dateien
- API-Dokumentation
- Fehlermeldungen in Logs
- technische Konfigurationsbeschreibungen

Spielertexte dürfen über das Locale-System übersetzt werden.

### 13.1 Benennung

Beispiele:

```ts
getConversationById()
createServiceRequest()
validateMessageContent()
hasCompanyPermission()
archiveAnonymousConversation()
```

Nicht verwenden:

```ts
holeChat()
machAnfrage()
prüfeRolle()
```

### 13.2 Dokumentation

Öffentliche Funktionen und komplexe interne Funktionen müssen dokumentiert werden.

TypeScript:

```ts
/**
 * Creates a new service request after validating the sender,
 * company availability and request payload.
 *
 * @param input - Validated request creation data.
 * @returns The persisted service request.
 * @throws AppError when the request cannot be created.
 */
async function createServiceRequest(
    input: CreateServiceRequestInput
): Promise<ServiceRequest> {
    // ...
}
```

Lua:

```lua
---Creates a new service request.
---@param source number Player source
---@param input CreateServiceRequestInput
---@return ServiceRequest? request
---@return string? errorCode
local function createServiceRequest(source, input)
    -- ...
end
```

Kommentare sollen erklären, warum etwas geschieht. Offensichtliche Codezeilen müssen nicht kommentiert werden.

---

## 14. API- und Event-Konventionen

### 14.1 Eventnamen

Eventnamen müssen eindeutig und namespaced sein.

```text
resource-name:server:createRequest
resource-name:server:updateRequest
resource-name:client:requestCreated
resource-name:client:requestUpdated
```

### 14.2 Datenverträge

Frontend, Client und Server müssen dieselben fachlichen Datenmodelle verwenden.

Für jedes Event werden dokumentiert:

- Name
- Richtung
- Eingabe
- Ausgabe
- mögliche Fehler
- benötigte Berechtigung
- Rate Limit
- Seiteneffekte

### 14.3 Rückgabeformat

```ts
type ApiResult<T> =
    | {
          success: true;
          data: T;
      }
    | {
          success: false;
          error: {
              code: string;
              message: string;
          };
      };
```

Keine Funktion soll je nach Situation völlig unterschiedliche Rückgabeformen besitzen.

---

## 15. Logging und Diagnose

Logs sollen strukturiert, sparsam und hilfreich sein.

### 15.1 Log-Level

- `debug`: detaillierte Entwicklungsinformationen
- `info`: relevante normale Aktionen
- `warn`: unerwartete, aber abgefangene Zustände
- `error`: fehlgeschlagene oder inkonsistente Vorgänge

### 15.2 Logs enthalten

- Resource
- Aktion
- Spielerquelle
- fachliche ID
- Fehlercode
- Request-ID
- relevante Dauer

### 15.3 Logs enthalten niemals

- Passwörter
- Tokens
- API Keys
- vollständige private Nachrichten
- unnötige personenbezogene Daten
- komplette Request-Payloads mit sensiblen Inhalten

Für Produktionsumgebungen muss Debug-Logging deaktivierbar sein.

---

## 16. Kontinuierliche Codeüberprüfung

Codeüberprüfung erfolgt nicht erst am Ende einer Entwicklungsphase.

### 16.1 Review-Zeitpunkte

Eine Überprüfung findet mindestens statt:

1. Nach Erstellung des Grundgerüsts
2. Nach Abschluss jedes größeren Features
3. Nach Änderungen am Datenmodell
4. Nach Änderungen an Berechtigungen
5. Nach Änderungen an Network Events
6. Nach Änderungen an Echtzeit-Synchronisierung
7. Vor jedem Merge
8. Vor jedem Release
9. Nach jedem größeren Bugfix
10. Nach Performance-Problemen

### 16.2 Inhalt jedes Reviews

Bei jeder Prüfung werden kontrolliert:

- Kann der Client die Aktion manipulieren?
- Ist jede Berechtigung serverseitig geprüft?
- Sind Inputs vollständig validiert?
- Werden unnötige Daten übertragen?
- Gibt es doppelte Queries?
- Gibt es Queries innerhalb von Schleifen?
- Werden Events unnötig global versendet?
- Werden Callback-Antworten garantiert ausgeführt?
- Können Race Conditions entstehen?
- Gibt es doppelte Event Listener?
- Werden Timer und Listener entfernt?
- Werden Fehler sauber behandelt?
- Sind Datenverträge typisiert?
- Ist der Code verständlich benannt?
- Ist komplexe Logik dokumentiert?
- Ist eine Funktion zu groß?
- Gibt es duplizierte Logik?
- Kann ein Request doppelt verarbeitet werden?
- Funktioniert ein Resource-Restart?
- Bleiben veraltete Cache-Daten zurück?
- Funktioniert die App bei hoher Latenz?

Kein Feature wird nur aufgrund eines erfolgreichen manuellen Happy-Path-Tests freigegeben.

---

## 17. Tests

### 17.1 Pflichtkategorien

#### Funktionstests

- Erstellen
- Lesen
- Bearbeiten
- Löschen oder Archivieren
- Suchen
- Sortieren
- Filtern
- Pagination
- Rollenwechsel
- Statuswechsel

#### Berechtigungstests

- normaler Benutzer
- Mitarbeiter
- Dispatcher
- Leitung
- nicht berechtigter Benutzer
- Benutzer eines anderen Unternehmens
- manipulierter Event-Aufruf
- veraltete Sitzung

#### Netzwerk- und Stabilitätstests

- hohe Latenz
- doppelte Requests
- verlorene Antworten
- Events in falscher Reihenfolge
- Resource-Restart
- LB-Phone-Restart
- Server-Restart
- Spieler verlässt während einer Aktion den Server
- Zielspieler ist offline
- Datenbank ist vorübergehend langsam
- sehr große Listen
- mehrere gleichzeitige Benutzer

#### UI-Tests

- unterschiedliche Auflösungen
- heller Modus
- dunkler Modus
- lange Namen
- lange Texte
- leere Zustände
- Ladezustände
- Fehlermeldungen
- schnelles mehrfaches Klicken
- schnelles Öffnen und Schließen
- Scrollpositionen
- Tastatur- und Eingabefokus

LB Phone setzt für Custom Apps abhängig von der Telefoneinstellung automatisch `data-theme` auf `dark` oder `light`. Beide Modi müssen geprüft werden.

---

## 18. Performance-Messung

Performance darf nicht nur subjektiv beurteilt werden.

### 18.1 FiveM Resource Monitor

Während der Entwicklung soll regelmäßig `resmon` verwendet werden.

```text
resmon true
```

### 18.2 FiveM Profiler

Für Client- und Serverprobleme wird der FiveM Profiler verwendet.

```text
profiler record 500
profiler status
profiler view
profiler saveJSON profile.json
```

Der Profiler kann problematische Threads bis hin zu Dateien und Zeilen sichtbar machen.

### 18.3 Browser-Tools

Für das Frontend sind regelmäßig zu prüfen:

- JavaScript-Ausführungszeit
- Re-Renders
- Speicherverbrauch
- Event Listener
- Netzwerkanfragen
- große Bundles
- lange Tasks
- Layout Shifts
- nicht freigegebene Object URLs
- weiterlaufende Timer nach dem Schließen

### 18.4 Performance-Budgets

Für jede App sollen eigene Zielwerte definiert werden.

Beispiele:

- Kein dauerhaft aktiver Client-Thread ohne tatsächlichen Bedarf
- Keine Polling-Schleifen im Sekundentakt
- Keine unlimitierte Listenabfrage
- Keine globalen Events für benutzerspezifische Updates
- Keine langen synchronen Serveroperationen
- Keine vermeidbaren Datenbankabfragen pro UI-Render
- Keine dauerhaft wachsenden Client-Caches

Konkrete Grenzwerte werden anhand realer Messungen und der Zielservergröße festgelegt.

---

## 19. Abhängigkeiten

Jede zusätzliche Abhängigkeit erhöht:

- Bundle-Größe
- Ladezeit
- potenzielle Sicherheitsprobleme
- Update-Aufwand
- Fehlerquellen
- Kompatibilitätsrisiken

Vor der Aufnahme einer Dependency wird geprüft:

1. Wird sie wirklich benötigt?
2. Ist die Funktion nicht bereits in LB Phone vorhanden?
3. Wird sie noch gepflegt?
4. Wie groß ist sie?
5. Funktioniert sie in FiveM NUI?
6. Kann dieselbe Aufgabe mit wenig eigenem Code gelöst werden?
7. Welche Lizenz besitzt sie?

LB Phone stellt bereits verschiedene UI-Komponenten und Funktionen bereit, darunter Popup-Menüs, Kontextmenüs, Kontaktwahl, Galerie, Emoji- und GIF-Auswahl, Karten, Medienupload und Kameraunterstützung.

---

## 20. Resource-Lifecycle und Restart-Sicherheit

Jede Resource muss Restart-sicher entwickelt werden.

Beim Start:

- Abhängigkeiten prüfen
- App registrieren
- Konfiguration laden
- benötigte Caches kontrolliert aufbauen
- Event Handler einmalig registrieren
- Datenbankversion prüfen

Beim Stop:

- App entfernen
- Timer stoppen
- temporäre Zustände löschen
- Caches freigeben
- offene serverseitige Vorgänge sauber beenden
- dynamisch erstellte LB-Phone-Komponenten entfernen

Mehrfache Registrierung derselben Listener oder App muss verhindert werden.

---

## 21. Versionsverwaltung

### 21.1 Branches

Beispiele:

```text
main
develop
feature/service-requests
feature/anonymous-conversations
fix/duplicate-message-event
refactor/message-repository
```

### 21.2 Commit Messages

Commit Messages werden auf Englisch geschrieben.

```text
feat: add service request assignment
fix: prevent duplicate anonymous conversations
refactor: move permission checks into service layer
perf: reduce conversation synchronization payload
docs: document message event contracts
test: add company permission validation tests
```

### 21.3 Versionierung

Semantische Versionierung:

```text
MAJOR.MINOR.PATCH
```

- `MAJOR`: inkompatible Änderungen
- `MINOR`: neue kompatible Funktionen
- `PATCH`: Fehlerkorrekturen

Jede Veröffentlichung erhält einen Eintrag im `CHANGELOG.md`.

---

## 22. Release-Checkliste

Vor einer Veröffentlichung muss Folgendes erfüllt sein:

- [ ] TypeScript kompiliert ohne Fehler.
- [ ] Linter meldet keine relevanten Probleme.
- [ ] Alle NUI Callbacks antworten garantiert.
- [ ] Alle Events sind dokumentiert.
- [ ] Alle Clientinputs werden serverseitig validiert.
- [ ] Berechtigungen wurden gezielt getestet.
- [ ] Rate Limits sind aktiv.
- [ ] Große Listen sind paginiert.
- [ ] Keine unnötigen Broadcasts vorhanden.
- [ ] Keine Datenbankabfragen in Schleifen vorhanden.
- [ ] Datenbankindizes wurden geprüft.
- [ ] Resource-Restart wurde getestet.
- [ ] LB-Phone-Restart wurde getestet.
- [ ] Server-Restart wurde getestet.
- [ ] Dark Mode wurde getestet.
- [ ] Light Mode wurde getestet.
- [ ] Fehlende und leere Daten wurden getestet.
- [ ] Hohe Latenz wurde simuliert.
- [ ] Doppelte Requests wurden getestet.
- [ ] Resmon wurde geprüft.
- [ ] Client- und Serverprofil wurden bei kritischen Funktionen geprüft.
- [ ] Produktions-Build wurde erstellt.
- [ ] Entwicklungsdateien wurden entfernt.
- [ ] Datenbankmigration und Rollback wurden dokumentiert.
- [ ] Backup-Anweisungen sind vorhanden.
- [ ] README und Changelog sind aktuell.

---

## 23. Definition of Done

Ein Feature ist nur dann abgeschlossen, wenn:

1. Die Funktion fachlich vollständig ist.
2. Die UI flüssig und verständlich funktioniert.
3. Alle Entscheidungen serverseitig abgesichert sind.
4. Alle Eingaben validiert werden.
5. Netzwerkdaten minimiert wurden.
6. Datenbankzugriffe optimiert sind.
7. Fehlerzustände behandelt werden.
8. Restart- und Disconnect-Szenarien funktionieren.
9. Code und technische Dokumentation auf Englisch vorliegen.
10. Ein eigenständiges Code-Review durchgeführt wurde.
11. Relevante Tests bestanden wurden.
12. Performance mit geeigneten Werkzeugen geprüft wurde.
13. Keine bekannten kritischen oder hohen Fehler mehr bestehen.
14. Die offizielle LB-Phone- und FiveM-Dokumentation erneut auf relevante Änderungen geprüft wurde.

---

## 24. Oberste Entwicklungsprinzipien

> The server is authoritative.

> Never trust client-provided data.

> Send the smallest possible payload to the smallest possible audience.

> Prefer events over polling.

> Load initial data only when the UI is ready.

> Use official LB Phone exports instead of bypassing the integration layer.

> Every callback must return a response.

> Every write operation must be validated and rate-limited.

> Optimize after measuring, but avoid obviously wasteful architecture from the beginning.

> Review code continuously, not only before release.

> Stable and maintainable code is more valuable than a quickly assembled feature.

> A smooth interface must never come at the cost of server security or data integrity.

> A secure backend must never be used as an excuse for a slow or unresponsive interface.
