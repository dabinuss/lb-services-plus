# PeekPlus – Architektur- und Migrationsplan

## Implementierungsstand – 13. August 2026

Die Code-Migration ist umgesetzt:

- generischer PeekPlus-Core und öffentliche Client-Exports
- separater LB-Phone-Adapter und Services+-Requestadapter
- Owner-Isolation, Queue, Interrupt/Suspend, Revisionen und Action-Tokens
- feste Hotkeys, Zwei-Schritt-Bestätigung und Action-in-flight-Sperre
- serverseitiger Settings-Initial-Sync und clientseitige Settings-Updates
- sicherer DOM-Fallback, Observer-Debounce und vollständiges Cleanup
- NUI-Rehydration, LB-Phone-Reconnect und Call-Priorität
- API-Dokumentation und zweite optionale Test-Consumer-Resource

Syntax-, Zustands-, Adapter-, Settings-, DOM- und Produktions-Buildtests sind
lokal erfolgreich. Die bisherigen Peek-Dateien bleiben vorerst ungeladen als
Verhaltensreferenz erhalten, bis der bestehende F8-/Ingame-Abnahmelauf auf dem
Server bestätigt wurde. Es werden niemals alter und neuer Controller parallel
geladen.

## 1. Ziel

PeekPlus wird die generische Notification- und Phone-Peek-Schicht von
Services+. Es wird **innerhalb der bestehenden `services-plus`-Resource**
ausgeliefert und ist keine zusätzliche FiveM-Resource.

PeekPlus kapselt den gesamten Sibling-NUI-Hack und stellt ein einheitliches
Verhalten für Services+ sowie andere Resources bereit:

- LB Phone mit der nativen Animation in den Peek-Zustand bringen
- einen Peek zeitlich begrenzt oder dauerhaft halten
- Karten im geöffneten Lockscreen in LB Phones nativen Notification-Stack
  einsetzen
- eingehenden und aktiven Anrufen immer Vorrang geben
- Aktionen per Button und Tastatur anbieten
- optionale Zwei-Schritt-Bestätigungen darstellen
- konkurrierende Notifications zentral in einer Queue verwalten
- Sounds zentral drosseln und an die Telefoneinstellungen anpassen
- bei Phone-, Consumer- oder Resource-Lifecycle-Ereignissen sauber aufräumen

PeekPlus kennt keine Unternehmen, Mitarbeiter oder Services+-Requests. Die
fachliche Request-Logik bleibt in Services+ und verwendet PeekPlus nur als
Darstellungs- und Eingabeschicht.

### Leitprinzip der Migration

Der bestehende Peek funktioniert bereits gut und bildet deshalb die
verbindliche Verhaltensreferenz. Die Migration ist keine Gelegenheit für eine
gleichzeitige Neugestaltung von Animation, Geometrie, Kartenlayout oder
Requestablauf.

- Phase 1 darf ausschließlich Code verschieben und umbenennen.
- Jede Phase muss für sich lauffähig und anhand der bestehenden Testbefehle
  abnehmbar sein.
- Erst nach bestandener Abnahme einer Phase wird die nächste begonnen.
- Der alte Controller bleibt bis zum vollständigen Vergleich als
  Referenzdatei erhalten, wird aber nie parallel zum neuen Controller geladen.
- Änderungen an LB-Phone-Selektoren, Peek-Geometrie und Animation erfolgen nur
  bei einem konkret nachgewiesenen Fehler.
- Bei Unsicherheit gilt das heutige funktionierende Verhalten.

---

## 2. Auslieferung

Auf dem Server bleibt nur eine Resource erforderlich:

```cfg
ensure services-plus
```

Andere Resources greifen über Client-Exports von `services-plus` auf
PeekPlus zu. Sie benötigen keine weitere Installation, sollten
`services-plus` aber als Dependency eintragen oder dessen gestarteten Zustand
vor einem Aufruf prüfen.

PeekPlus erhält intern eine eigene Versionsnummer, unabhängig von der
Services+-Version. Diese Version wird beim Start im F8-Log ausgegeben und für
den CEF-Cache-Buster verwendet.

---

## 3. Geplante Verzeichnisstruktur

```text
services-plus/
├── client/
│   ├── peekplus/
│   │   ├── api.lua          # interne API und öffentliche Client-Exports
│   │   ├── controller.lua   # Queue, Zustände, Hotkeys und Lifecycle
│   │   ├── lbphone.lua      # LB-Phone-Erkennung und Zustandsadapter
│   │   └── debug.lua        # optionale F8-Testbefehle
│   └── services/
│       └── requests.lua     # Services+-Adapter für Request-Ereignisse
├── ui/
│   └── peekplus/
│       ├── index.html
│       ├── controller.js    # Sibling-NUI- und DOM-Controller
│       └── styles.css
├── shared/
│   └── peekplus.lua         # Defaults und feste Grenzwerte
└── fxmanifest.lua
```

Die endgültigen Dateinamen dürfen an die vorhandene Struktur angepasst
werden. Entscheidend ist die klare Grenze zwischen PeekPlus und der
Services+-Requestlogik.

---

## 4. Verantwortungsgrenzen

### PeekPlus

PeekPlus ist verantwortlich für:

- Erstellen, Aktualisieren und Entfernen visueller Karten
- Zustandswechsel einer Karte
- Queue, Priorität und genau einen sichtbaren Peek
- Phone-Peek-Animation und Peek-Lock
- Lockscreen-Integration
- Call-Priorität
- Hotkey-Arbitration
- Bestätigungszustände
- Notification-Sound und Sound-Throttling
- Besitzerzuordnung und Aufräumen
- DOM-Kompatibilitätsprüfung und Fallback

### Services+

Services+ ist weiterhin verantwortlich für:

- Berechtigungen und Duty-State
- Annahme, Ablehnung, Abbruch und Abschluss eines Requests
- Servercallbacks und Datenbankänderungen
- First-accept-wins
- Request-Rehydration
- Wegpunkte und Distanzdaten
- Entscheidung, welche Inhalte und Aktionen angezeigt werden

PeekPlus meldet lediglich eine Aktion. Eine Karte darf erst nach erfolgreicher
fachlicher Verarbeitung in einen neuen Zustand wechseln.

---

## 5. Zustandsmodell

Jede PeekPlus-Karte besitzt einen stabilen, nicht wiederverwendeten Schlüssel
aus Runtime-ID, Owner und Counter und durchläuft explizite Zustände:

```text
queued -> pending -> active -> removed
                    |       -> completed
                    -> declined
```

Die Zustände bedeuten:

- `queued`: wartet hinter einer bereits sichtbaren Karte
- `pending`: neue Notification mit Annahme-/Ablehnungsaktionen
- `active`: angenommen und standardmäßig dauerhaft gehalten
- `removed`: vom Owner oder Lifecycle entfernt
- `completed`/`declined`: optionale kurze Endzustände vor dem Entfernen

Eine Aktualisierung verändert dieselbe Karten-ID. Es wird keine zweite
Notification erzeugt. Dadurch entstehen weder doppelte Animationen noch
nachlaufende Sounds.

Für jede Karte speichert PeekPlus mindestens:

```lua
{
    id = "peekplus:<runtime>:<owner>:<counter>",
    owner = "consumer-resource",
    revision = 1,
    state = "pending",
    title = "Taxi pickup",
    subtitle = "Downtown Cab",
    description = "Customer is waiting",
    duration = 15000,
    hold = false,
    sound = true,
    priority = 0,
    actions = {},
    createdAt = 0,
    expiresAt = 0,
}
```

Die zufällige Runtime-ID wird bei jedem Start von `services-plus` neu erzeugt.
Dadurch kann eine verspätete NUI-Aktion nach einem Neustart nicht versehentlich
eine neue Karte mit demselben Counter treffen. Jede erfolgreiche Aktualisierung
erhöht zusätzlich `revision`.

Erlaubte Übergänge werden zentral als feste Übergangsmatrix definiert:

```text
queued  -> pending | removed
pending -> active | declined | removed
active  -> completed | declined | removed
completed/declined -> removed
```

Rückwärtsübergänge wie `completed -> pending` und Updates auf bereits entfernte
Karten werden abgelehnt. Die Services+-Rehydration erstellt bei Bedarf eine
neue `active`-Karte.

`active` verwendet standardmäßig `hold = true`. Es bleibt erhalten, bis der
Owner es entfernt, aktualisiert oder eine erfolgreiche Endaktion verarbeitet
wurde.

---

## 6. Öffentliche Client-API

Die API wird sowohl intern als Lua-Modul als auch extern über Client-Exports
angeboten.

### Karte anzeigen

```lua
local peekId = exports["services-plus"]:ShowPeek({
    title = "Medical Emergency",
    subtitle = "Pillbox Medical",
    description = "2 injured people · Legion Square",
    duration = 15000,
    sound = true,
    actions = {
        {
            id = "decline",
            label = "Decline",
            key = "DELETE",
        },
        {
            id = "accept",
            label = "Accept",
            key = "RETURN",
        },
    },
})
```

### Bestehende Karte aktualisieren

```lua
exports["services-plus"]:UpdatePeek(peekId, {
    state = "active",
    description = "Request accepted",
    hold = true,
    actions = {
        {
            id = "cancel",
            label = "Cancel",
            key = "DELETE",
            confirm = {
                label = "Confirm?",
            },
        },
    },
})
```

### Karte entfernen

```lua
exports["services-plus"]:RemovePeek(peekId)
```

### Alle eigenen Karten entfernen

```lua
exports["services-plus"]:ClearPeeks()
```

### Aktion empfangen

Aktionen werden über ein Client-Event an den Owner zurückgegeben:

```lua
AddEventHandler("peekplus:action", function(data)
    -- data.id
    -- data.action
    -- data.confirmed
    -- data.revision
    -- data.actionToken
end)
```

Das endgültige Eventformat muss verhindern, dass Consumer auf Aktionen
anderer Consumer reagieren. Dafür enthält jedes Ereignis den Owner und wird
zusätzlich über eine owner-spezifische Eventbezeichnung angeboten:

```text
peekplus:action:<resource-name>
```

`GetInvokingResource()` bestimmt bei Exports den tatsächlichen Owner. Ein vom
Consumer übergebenes `owner`-Feld wird ignoriert. Ein Consumer darf nur seine
eigenen Karten aktualisieren oder entfernen.

Owner-spezifische Client-Events sind eine Zuordnungsgrenze, aber keine
Sicherheitsgrenze gegen manipulierte Clients. Jede fachliche Aktion bleibt
serverseitig autoritativ und wird dort erneut auf Berechtigung, Requestzustand
und First-accept-wins geprüft.

Alle Eingaben werden validiert und begrenzt:

- maximale Textlängen
- erlaubte Zustände
- maximale Anzahl Aktionen
- erlaubte Hotkeys
- begrenzte Duration und Priorität
- keine HTML-Ausführung; Texte werden immer escaped

Version 1 akzeptiert nur eine kleine, zentral registrierte Hotkey-Allowlist,
zunächst `RETURN` und `DELETE`. Die zugehörigen `RegisterKeyMapping`-Commands
werden genau einmal statisch registriert und jeweils nur an die Action der
aktuell sichtbaren Karte weitergeleitet. Beliebige dynamische Key-Mappings sind
kein Bestandteil von Version 1.

---

## 7. Aktionen und Bestätigungen

PeekPlus verwaltet Actions generisch. Die Engine kennt beispielsweise nicht
die Bedeutung von `accept` oder `cancel`.

Eine Action kann enthalten:

```lua
{
    id = "cancel",
    label = "Cancel",
    key = "DELETE",
    color = "danger",
    confirm = {
        label = "Confirm?",
        timeout = 5000,
    },
}
```

Verhalten bei `confirm`:

1. erster Tastendruck oder Klick aktiviert den Bestätigungszustand
2. der Button wechselt auf `Confirm?`
3. derselbe Tastendruck oder Klick bestätigt die Aktion
4. eine andere Aktion, ein Zustandswechsel oder das optionale Timeout setzt
   die Bestätigung zurück
5. erst die bestätigte Aktion wird an den Consumer gesendet

Beim Auslösen einer Action setzt PeekPlus die Karte sofort auf
`actionInFlight`. Pointer und Hotkey dieser Karte bleiben gesperrt, bis der
Consumer sie erfolgreich aktualisiert oder entfernt, die Action explizit
freigibt oder ein begrenzter Timeout abläuft.

Das Ereignis enthält `revision` und einen einmaligen `actionToken`. Antworten
oder Aktualisierungen, die nicht mehr zur aktuellen Revision passen, dürfen
keinen neueren Kartenstand überschreiben. Damit erzeugen Doppelklicks,
Key-Repeat und verspätete Serverantworten keine doppelten Aktionen.

Services+ konfiguriert für aktive Requests `DELETE` mit Bestätigung. Pending
Requests verwenden `DELETE` weiterhin als direkte Ablehnung und `ENTER` als
Annahme.

---

## 8. Queue und Prioritäten

Es darf global nur einen durch PeekPlus kontrollierten Peek geben.

Grundregeln:

- neue Karten werden nach Priorität und Erstellzeit eingeordnet
- eine sichtbare Karte wird nicht durch eine Karte gleicher Priorität neu
  animiert
- Updates derselben Karten-ID ersetzen niemals die Karte in der Queue
- ein aktiver, dauerhaft gehaltener Eintrag bleibt sichtbar
- weitere Einträge warten standardmäßig, bis der aktive Eintrag endet; dieses
  Verhalten entspricht dem bestehenden Services+-Ablauf
- eine Karte darf nur mit `interrupt = true` und einer strikt höheren Priorität
  einen gehaltenen Eintrag vorübergehend verdrängen
- der verdrängte Eintrag behält ID, Revision und fachlichen Zustand und wird
  danach ohne neuen Sound oder neue fachliche Aktion wiederhergestellt
- gleiche Priorität verdrängt niemals eine sichtbare Karte
- Queue-Länge und Anzahl der Karten pro Owner werden begrenzt; bei Erreichen
  des Limits wird `ShowPeek` mit einem Fehler abgelehnt
- Sounds werden pro neuer Karte höchstens einmal abgespielt
- schnell aufeinanderfolgende Sounds werden global gedrosselt

Die erste Version benötigt keine komplexen Multi-Card-Stacks im Peek. Der
Lockscreen darf die eine von PeekPlus aktive Karte zusammen mit nativen
LB-Phone-Notifications anzeigen.

Eine verdrängte oder wegen eines Calls nicht bedienbare Karte befindet sich nur
darstellerisch in `suspended`; ihr fachlicher Status bleibt unverändert.

---

## 9. Phone- und Lockscreen-Verhalten

### Handy geschlossen

- PeekPlus animiert LB Phones `.phoneVisbility`-Wrapper aus dem geschlossenen
  Zustand in den Peek-Zustand.
- Ein zeitlicher Peek fährt nach Ablauf wieder herunter.
- Ein gehaltener aktiver Peek bleibt oben, bis er fachlich endet oder das
  Handy vollständig geöffnet wird.

### Handy wird vollständig geöffnet

- PeekPlus gibt seinen Geometrie-Lock sofort frei.
- Die Karte wird aus der normalen Peek-Position entfernt.
- Wenn LB Phones `.lockscreen-notification-container` vorhanden ist, wird die
  Karte als Element dieses nativen Flex-Stacks eingesetzt.
- Dadurch liegt sie unter Uhr und Lockscreen-Widgets und verschiebt sich mit
  nativen Notifications.
- Ist der Nutzer bereits auf Homescreen oder in einer App und existiert kein
  Lockscreen-Container, wird die Karte nicht über den Inhalt gelegt.

### Handy wird geschlossen

- eine aktive/held Karte wird wieder im Peek angezeigt
- eine pending Karte wird nur wiederhergestellt, solange ihre ursprüngliche
  Laufzeit nicht abgelaufen ist
- es wird kein neuer Sound abgespielt und keine zweite Karte erzeugt

### Handy nicht verfügbar

Wenn kein ausgerüstetes oder verwendbares Telefon existiert, nutzt PeekPlus
abhängig von `Config.PeekPlus.rootFallback` entweder einen sicheren
Root-NUI-Fallback oder zeigt bewusst nichts an. Der Fallback verändert niemals
den LB-Phone-Wrapper. Für die Migration bleibt der heutige Fallback-Standard
unverändert.

---

## 10. Call-Priorität

LB Phone hat immer Vorrang bei eingehenden und aktiven Calls.

PeekPlus beobachtet die offiziellen LB-Phone-State-Bags, insbesondere
`onCallWith`, und wendet folgende Regeln an:

- die Request-Karte bleibt sichtbar
- sie wird unter die Call-Anzeige verschoben
- LB Phones Call-UI liegt im Z-Index über PeekPlus
- PeekPlus deaktiviert Pointer-Aktionen während des Calls
- PeekPlus ignoriert seine Hotkeys während des Calls
- `ENTER`, `DELETE` und andere kollidierende Eingaben erreichen damit nur LB
  Phone
- während eines Calls wird kein zusätzlicher PeekPlus-Sound abgespielt
- nach Call-Ende wird dieselbe Karte wieder bedienbar

„Sichtbar“ und „bedienbar“ sind getrennte Eigenschaften: Während eines Calls
bleibt die Karte sichtbar, ist für Eingaben aber `suspended`. Ihr fachlicher
Zustand und ihre Queue-Position ändern sich nicht.

PeekPlus erzeugt für einen Call keine eigene Notification und verändert keine
Call-Daten.

---

## 11. LB-Phone-Adapter und DOM-Kompatibilität

Alle LB-Phone-spezifischen Annahmen befinden sich an einer Stelle:

- Export-Prüfungen (`IsOpen`, `IsDisabled`, `IsPhoneDead`, Einstellungen)
- State-Bags und Phone-Events
- DOM-Selektoren
- native Peek-Geometrie
- Lockscreen-Container
- Call-Z-Index und Abstände

`IsOpen`, `IsDisabled` und `IsPhoneDead` werden weiterhin über geprüfte
Client-Exports gelesen. Die initialen LB-Phone-Einstellungen werden dagegen
nicht über einen unbestätigten clientseitigen `GetSettings()`-Aufruf geladen.
Der Server löst die ausgerüstete Telefonnummer auf, ruft dort
`GetSettings(phoneNumber)` auf und synchronisiert nur die benötigten
Sound-/Notification-Werte an den Client. Das Event
`lb-phone:settingsUpdated` aktualisiert den Runtime-State anschließend weiter.
Schlägt der Initial-Sync fehl, gelten die bisherigen sicheren Sound-Defaults.

Beim Verbinden prüft PeekPlus mindestens:

- CitizenFX-Root-Dokument erreichbar
- LB-Phone-iframe vorhanden
- `.full-phone` vorhanden
- `.phoneVisbility` vorhanden
- Lockscreen-Container bei geöffnetem Lockscreen optional vorhanden

Eine unbekannte oder geänderte LB-Phone-Struktur darf nicht zu einem dauerhaft
sichtbaren Handy oder blockierten Input führen. PeekPlus protokolliert die
fehlende Fähigkeit einmalig und fällt auf die sichere Root-Darstellung zurück.

LB-Phone-Dateien werden niemals verändert. Sämtliche Styles und Elemente
werden zur Laufzeit eingefügt und beim Stop wieder entfernt.

`styles.css` wird nicht als bereits im fremden Dokument geladen vorausgesetzt.
PeekPlus injiziert dort ein eindeutig markiertes `<style>` beziehungsweise
einen Resource-Stylesheet-Link und entfernt genau dieses Element beim Cleanup.

DOM-Observer beobachten nur die kleinsten erforderlichen Wurzeln. Ihre
Callbacks werden über `requestAnimationFrame` zusammengefasst; ein Render läuft
nur, wenn sich Host, Karte, Revision, Phone-Zustand oder Geometrie tatsächlich
geändert haben. Damit lösen Appwechsel und Listenupdates im LB Phone keine
unnötigen vollständigen Renders aus.

---

## 12. Lifecycle und Ownership

PeekPlus muss folgende Fälle behandeln:

- `services-plus` stoppt: DOM, Styles, Timer, Observer, Hotkeys und Locks
  vollständig entfernen
- Consumer stoppt: alle Karten dieses Owners entfernen
- LB Phone stoppt/restartet: Lock freigeben, Verbindung später neu aufbauen
- NUI lädt neu: aktuellen Zustand ohne Sound und ohne neue Animation
  rehydrieren
- Spieler öffnet Kamera: zeitlichen, unterbrechbaren Peek freigeben
- Spieler öffnet das Handy: Geometrie freigeben und Lockscreen-Integration
  verwenden
- Spieler schließt das Handy: held Peek wiederherstellen
- Call beginnt/endet: Priorität ohne Verlust der Karte wechseln
- verspätete NUI-Aktion aus einer alten Runtime: anhand Runtime-ID, Revision und
  Action-Token ignorieren

Consumer-Cleanup wird über `onClientResourceStop` zentral durchgeführt. Der
Name der stoppenden Resource wird mit dem gespeicherten Owner verglichen.

---

## 13. Services+-Adapter

Der heutige Request-Overlay-Code wird auf einen schmalen Adapter reduziert.

### Neuer Request

Services+ ruft `PeekPlus.Show()` mit folgenden Actions auf:

- `decline`, Taste `DELETE`
- `accept`, Taste `RETURN`

### Erfolgreiche Annahme

Erst nach erfolgreichem Servercallback aktualisiert Services+ dieselbe Karte:

- `state = "active"`
- `hold = true`
- Text „Request accepted“
- `cancel`, Taste `DELETE`, mit `Confirm?`
- optional `complete` als Button ohne globalen Hotkey

### Ablehnung, Abbruch oder Abschluss

Nach erfolgreicher fachlicher Verarbeitung entfernt Services+ die Karte.
Bei einem Serverfehler bleibt sie im passenden Zustand oder wird anhand des
Serverzustands rehydriert.

### Rehydration

Bei Resource- oder NUI-Neustart fragt Services+ weiterhin den aktiven Request
vom Server ab und erstellt daraus eine `active`/held PeekPlus-Karte. PeekPlus
selbst greift niemals auf die Services+-Datenbank zu.

---

## 14. Test- und Debug-API

Die bisherigen F8-Befehle werden in PeekPlus verschoben und testen dieselbe
öffentliche API wie externe Consumer:

```text
peekplus_test 15
peekplus_test hold
peekplus_test_hold
peekplus_test stop
```

Der Testablauf muss mindestens prüfen:

1. pending Karte erscheint mit Animation und genau einem Sound
2. `ENTER` wechselt auf active/held
3. erstes `DELETE` zeigt `Confirm?`
4. zweites `DELETE` entfernt die Karte
5. Öffnen des Handys zeigt die Karte im Lockscreen-Stack unter der Uhr
6. native Notifications können gleichzeitig im Stack erscheinen
7. Homescreen und Apps werden nicht überdeckt
8. Schließen stellt die active Karte im Peek wieder her
9. ein Call hat visuell und bei Eingaben Vorrang
10. schnelle Wiederholungen erzeugen keine Doppel-Peeks oder Soundketten
11. Consumer-Stop entfernt nur dessen eigene Karten
12. Services+-Stop hinterlässt keine DOM-Elemente oder Phone-Locks
13. Doppelklick und gehaltene Taste senden pro Revision nur eine Action
14. eine verspätete Action einer alten Revision oder Runtime wird ignoriert
15. ein explizit höher priorisierter Interrupt stellt den gehaltenen Peek ohne
    zweiten Sound wieder her
16. Settings-Initial-Sync und `settingsUpdated` respektieren Lautlos/DND
17. DOM-Mutationsserien führen höchstens zu einem Render pro Animation Frame

---

## 15. Migrationsphasen

### Phase 1 – Extraktion ohne Verhaltensänderung

- vorhandenen JS-Controller nach `ui/peekplus/` verschieben
- Peek-, Call-, Sound- und Phone-Lifecycle aus `client/overlay.lua` nach
  `client/peekplus/` verschieben
- gegenwärtiges Verhalten unverändert halten
- bestehende Testcommands auf die interne PeekPlus-API umstellen
- vor und nach der Extraktion denselben Referenzablauf per Screenshot/Video und
  Zustandslog vergleichen
- keine Queue-, Layout-, Animations-, Settings- oder Hotkey-Semantik ändern

**Abnahme-Gate:** Erst wenn Pending, Accept, Active/Hold, Confirm/Cancel,
Lockscreen, Call-Priorität, Sound und Cleanup identisch funktionieren, beginnt
Phase 2.

### Phase 2 – Generisches Modell und interne API

- generisches Karten- und Action-Schema einführen
- Runtime-ID, Revisionen, Übergangsmatrix und Action-in-flight ergänzen
- Queue und Ownership zentralisieren
- explizite Interrupt-/Suspend-Regel sowie Queue-Limits ergänzen
- `Show`, `Update`, `Remove` und `ClearOwner` intern bereitstellen
- Services+-Requestadapter auf die neue API umstellen
- Services+-Begriffe aus PeekPlus entfernen

**Abnahme-Gate:** Der Services+-Adapter muss gegen dieselben serverseitigen
Callbacks arbeiten wie zuvor. Kein Action-Erfolg darf lokal vorweggenommen
werden.

### Phase 3 – Öffentliche Exports

- validierte Client-Exports veröffentlichen
- `GetInvokingResource()` für Ownership verwenden
- owner-spezifische Action-Events bereitstellen
- Consumer-Stop-Cleanup implementieren
- API-Dokumentation und Beispiele ergänzen
- feste Hotkey-Allowlist dokumentieren

**Abnahme-Gate:** Zuerst eine kleine lokale Test-Consumer-Resource verwenden;
öffentliche Exports erst danach als stabil markieren.

### Phase 4 – Robustheit und Kompatibilität

- Capability-/DOM-Prüfung ergänzen
- serverseitigen Initial-Sync der LB-Phone-Einstellungen ergänzen
- LB-Phone-Restart und NUI-Reconnect testen
- Root-Fallback testen
- Call-/Lockscreen-Kollisionen testen
- Sound- und Queue-Stresstest durchführen
- Observer-Debounce und Render-Deduplizierung messen

### Phase 5 – Bereinigung

- alten Request-spezifischen Overlay-Code entfernen
- Referenzcontroller erst jetzt entfernen
- alte Cache-Seiten und veraltete Konfiguration entfernen
- nur eine aktuelle PeekPlus-UI-Seite im Manifest führen
- README, API-Dokumentation und Entwicklungsplan aktualisieren
- Dev-/Build-Spiegelung und Live-Resource prüfen

---

## 16. Dokumentation

PeekPlus erhält einen eigenen Abschnitt in der Haupt-README und eine separate
API-Dokumentation, beispielsweise `PEEKPLUS.md`.

Diese Dokumentation enthält:

- Installation innerhalb von Services+
- Abhängigkeit für andere Resources
- vollständige Export-Signaturen
- Karten- und Action-Schema
- Action-Eventformat
- Ownership-Regeln
- Beispiel für pending -> active -> cancel
- Call- und Lockscreen-Verhalten
- bekannte Abhängigkeit von LB Phones DOM-Struktur
- Debugbefehle und erwartete Controller-Version

---

## 17. Abnahmekriterien

PeekPlus gilt als fertig, wenn:

- Services+ keine eigene Peek-/DOM-Implementierung mehr besitzt
- Services+ ausschließlich die interne PeekPlus-API verwendet
- eine zweite Test-Resource dieselbe API ohne Services+-Spezialwissen nutzen
  kann
- keine zusätzliche Server-Resource installiert werden muss
- pending, active/held und bestätigter Abbruch zuverlässig funktionieren
- Calls und native Lockscreen-Notifications parallel funktionieren
- das vollständige Handy jederzeit normal geöffnet und geschlossen werden kann
- aktive Karten danach korrekt in den Peek zurückkehren
- keine mehrfachen Peeks oder nachlaufenden Sounds entstehen
- keine doppelten Actions durch Klick, Key-Repeat oder verspätete Antworten
- gehaltene Karten werden nur nach der expliziten Interrupt-Regel verdrängt
- alle Owner- und Resource-Stop-Fälle sauber aufräumen
- ein unbekanntes LB-Phone-DOM sicher auf den Fallback wechselt
- LB-Phone-Soundeinstellungen werden initial serverseitig und danach über das
  Update-Event synchronisiert
- die Verhaltensreferenz aus Phase 1 bleibt für Services+ unverändert
- Dev- und Build-Ausgabe identisch und releasefähig sind

---

## 18. Nicht-Ziele

PeekPlus wird ausdrücklich nicht:

- als separate Resource ausgeliefert
- LB-Phone-Core-Dateien patchen
- serverseitige Geschäftslogik übernehmen
- Requests, Unternehmen oder Duty-Systeme kennen
- ein vollständiges Notification-Center ersetzen
- beliebiges HTML von Consumern rendern
- mehrere konkurrierende Hotkey-Systeme parallel zulassen

Damit bleibt PeekPlus klein, wiederverwendbar und innerhalb von Services+
wartbar, ohne für Serverbetreiber eine weitere Mod oder Resource einzuführen.
