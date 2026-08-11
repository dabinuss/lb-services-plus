# Services+ – Entwicklungsplan

## 1. Ziel

Services+ wird eine eigenständige LB-Phone-App, die sich optisch und funktional stark an der nativen Dienste-/Services-App von LB Phone orientiert, diese aber erweitert.

Wichtige Ziele:

- möglichst kleine und einfache Codebasis
- keine unnötig komplexen Systeme
- native oder stark an LB Phone angelehnte Optik
- hohe Performance
- für Server mit 600+ Spielern geeignet
- geringe Netzwerkbelastung
- Nutzung vorhandener Framework- und LB-Phone-Funktionen
- Kompatibilität mit typischen FiveM-Frameworks
- keine Änderungen direkt am LB-Phone-Core
- Tests hauptsächlich manuell auf dem lokalen Entwicklungsserver (E:\FiveMServer\txData\FiveMBasicServerCFXDefault_71E096.base\resources) bitte zwischen dev/ und dem server ein link herstellen sodass auf dem server IMMER der aktuelle build existiert

Services+ soll ausdrücklich kein komplexes Dispatch-, CAD- oder CRM-System werden.

---

# 2. Grundaufbau

Services+ wird als eigene FiveM-Resource entwickelt.

Beispiel:

```text
services-plus/
├── fxmanifest.lua
├── client/
├── server/
├── shared/
├── ui/
├── locales/
└── sql/
```

Die App wird über die normale LB-Phone-Custom-App-Schnittstelle registriert.

Die eigentliche Services+-App bleibt unabhängig vom Sibling-NUI-System.

Sibling-NUI wird ausschließlich für spezielle interaktive Notifications und Peek-Funktionen verwendet.

---

# 3. Benutzerbereiche

Services+ besitzt drei grundlegende Bereiche.

## Normaler Nutzer

Kann:

- Unternehmen durchsuchen
- Unternehmen anrufen
- Nachrichten senden
- Requests erstellen
- eigene Aktivitäten ansehen

## Unternehmensmitarbeiter

Kann zusätzlich:

- Unternehmensbereich öffnen
- Leitstellen übernehmen
- Mitarbeiterstatus setzen
- Calls empfangen
- Requests empfangen
- Nachrichten bearbeiten
- Requests verwalten
- Teamstatus ansehen

## Services+-Admin

Kann zusätzlich:

- Unternehmen konfigurieren
- Kategorien konfigurieren
- Telefonnummern verwalten
- Request-Typen konfigurieren
- Funktionen aktivieren/deaktivieren
- Unternehmensleiter festlegen

---

# 4. Navigation

Grundsätzlich wird eine horizontale Navigation am unteren Rand verwendet.

Die Navigation soll sich optisch an LB Phone orientieren.

## Normaler Nutzer

```text
Services | Activity
```

## Mitarbeiter

```text
Services | Activity | Company
```

## Admin

```text
Services | Activity | Company | Admin
```

Nicht verfügbare Bereiche werden nicht angezeigt.

---

# 5. Services-Übersicht

Die Hauptseite zeigt alle verfügbaren Unternehmen.

## Funktionen

- Suchleiste
- Kategorien
- Schnellsuche über Kategorie-Icons
- Unternehmensstatus
- Unternehmensaktionen

Beispielkategorien:

```text
Police
Medical
Taxi
Mechanic
Towing
Government
```

Weitere Kategorien können erstellt werden.

---

# 6. Unternehmenskarte

Jedes Unternehmen erhält eine eigene Karte.

Diese enthält:

- Unternehmensname
- Icon oder Logo
- eigenes Hintergrundbild
- Status
- verfügbare Aktionen

Mögliche Buttons:

```text
Call
Request
Message
```

Buttons werden nur angezeigt, wenn die Funktion für das Unternehmen verfügbar und aktiviert ist.

---

# 7. Verfügbarkeit von Unternehmen

Ein Unternehmen gilt grundsätzlich als verfügbar, wenn mindestens ein Mitarbeiter im Dienst ist.

Wenn niemand verfügbar ist, kann das Unternehmen abhängig von der Serverkonfiguration:

- ausgegraut angezeigt werden
- komplett ausgeblendet werden

Optional kann ein Status wie:

```text
Closed
Unavailable
No employees available
```

angezeigt werden.

---

# 8. Mehrere Telefonnummern

Jedes Unternehmen besitzt mindestens eine Telefonnummer.

## Haupttelefonnummer

Die Haupttelefonnummer:

- ist verpflichtend
- kann nicht gelöscht werden
- kann nicht vollständig deaktiviert werden

## Zusätzliche Telefonnummern

Administratoren können zusätzliche Telefonnummern hinzufügen.

Beispiele:

```text
Main Hotline
Emergency
Dispatch
Workshop
Management
```

Zusätzliche Telefonnummern können vom Unternehmen aktiviert oder deaktiviert werden.

---

# 9. Auswahl der Telefonnummer

Wenn ein Nutzer auf:

```text
Call
```

oder:

```text
Message
```

drückt und mehrere Telefonnummern verfügbar sind, erscheint eine native Auswahl.

Beispiel:

```text
Call

Main Hotline
Workshop
Management
```

Existiert nur eine mögliche Nummer, wird die Auswahl übersprungen.

---

# 10. Nachrichtenpostfächer

Für jede Telefonnummer kann festgelegt werden, ob diese ein eigenes Nachrichtenpostfach besitzt.

Beispiel:

```text
Main Hotline
→ eigenes Postfach

Workshop
→ eigenes Postfach

Management
→ Nachrichten deaktiviert
```

Unternehmen können zusätzliche Postfächer deaktivieren, sofern der Admin diese Funktion grundsätzlich erlaubt.

---

# 11. Requests

Requests sind spezielle Gameplay-Aufträge.

Sie sind ausdrücklich keine klassischen Support-Tickets, Reservierungen oder Bestellungen.

Beispiele:

```text
Taxi Pickup
Vehicle Towing
Roadside Assistance
Police Emergency
Medical Emergency
```

---

# 12. Request-Typen

Request-Typen werden konfigurierbar aufgebaut.

Ein Request-Typ kann enthalten:

- Name
- Icon
- Beschreibung
- automatischer Standort
- Personenanzahl
- optionales Textfeld
- Zielkategorie
- Konkurrenzmodus

Beispiel:

```text
Taxi Pickup

Icon: Taxi
Location: automatic
Passenger count: enabled
Description: optional
Category: Taxi
Competition: enabled
```

Dadurch müssen verschiedene Branchen nicht fest im Code implementiert werden.

---

# 13. Request-Status

Requests verwenden einen kleinen, einfachen Statusablauf.

```text
Open
Accepted
Active
Completed
Cancelled
```

Keine komplexeren Workflow-Systeme.

---

# 14. Request erstellen

Beim Erstellen eines Requests werden abhängig vom Request-Typ nur die benötigten Angaben abgefragt.

Beispiel Taxi:

```text
Passenger count
Optional note
Current location
```

Beispiel Abschleppdienst:

```text
Current location
Optional description
```

Beispiel Medical:

```text
Current location
Optional emergency description
```

Standorte werden nach Möglichkeit automatisch vom Client bestimmt.

Der Server muss lediglich prüfen, ob die übermittelten Daten plausibel und erlaubt sind.

---

# 15. Konkurrenz-Requests

Für bestimmte Kategorien können Unternehmen um Requests konkurrieren.

Beispiel:

```text
Taxi Company A
Taxi Company B
Taxi Company C
```

Ein Nutzer erstellt:

```text
Taxi Pickup
```

Der Request wird an alle geeigneten Taxiunternehmen verteilt.

Das erste Unternehmen, dessen Mitarbeiter den Request serverseitig erfolgreich annimmt, gewinnt.

Danach:

- wird der Request diesem Unternehmen zugeordnet
- verschwindet er bei allen anderen Unternehmen
- weitere Annahmen werden serverseitig abgelehnt

Die Entscheidung darf niemals ausschließlich clientseitig erfolgen.

---

# 16. Konkurrenzmodus konfigurieren

Der Wettbewerb kann abhängig von:

- Kategorie
- Request-Typ

aktiviert oder deaktiviert werden.

Beispiele:

```text
Taxi Pickup
Competition: enabled

Tow Request
Competition: enabled

Police Emergency
Competition: disabled

Medical Emergency
Competition: disabled
```

---

# 17. Unternehmensbereich

Unternehmensmitarbeiter erhalten einen eigenen Bereich.

Dieser ist nur sichtbar, wenn der Spieler zu einem unterstützten Framework-Job gehört.

---

# 18. Fake-Login

Beim ersten Öffnen des Unternehmensbereiches erscheint ein spielerischer Login.

Beispiel:

```text
Sign in to Downtown Cab Co.
```

Nach Klick auf Login:

- kurze Animation
- Benutzername wird automatisch eingetragen
- Fake-Passwort wird automatisch eingegeben
- Login wird abgeschlossen

Dies ist rein visuell.

Die tatsächliche Berechtigung wird weiterhin über den Server und das Framework geprüft.

---

# 19. Unternehmensdashboard

Nach dem Login erscheint eine einfache Übersicht.

Oben:

```text
Downtown Cab Co.

Dabi
Senior Driver
```

Zusätzlich:

- Mitarbeiterstatus
- aktive Hotlines
- aktuelle Requests
- Unternehmensstatus

---

# 20. Leitstellen und Hotlines

Mitarbeiter können Telefonnummern übernehmen.

Beispiel:

```text
Available Hotlines

[x] Main Hotline
[x] Airport Taxi
[ ] VIP Service
```

Mehrfachauswahl ist erlaubt.

---

# 21. Hauptleitstelle

Die Haupttelefonnummer besitzt eine Sonderregel.

Sie muss immer von mindestens einem Mitarbeiter im Dienst übernommen werden.

Ist nur ein Mitarbeiter im Dienst:

- wird die Hauptleitstelle automatisch aktiviert
- kann dieser Mitarbeiter sie nicht deaktivieren

Sobald weitere Mitarbeiter verfügbar sind, kann die Leitstelle normal verteilt werden.

---

# 22. Mehrere Mitarbeiter pro Hotline

Mehrere Mitarbeiter dürfen dieselbe Telefonnummer gleichzeitig übernehmen.

Dadurch wird keine komplizierte Dispatcher-Struktur benötigt.

Beispiel:

```text
Main Hotline

Dabi
John
Michael
```

Alle drei können Anfragen für diese Hotline erhalten.

---

# 23. Mitarbeiterstatus

Jeder Mitarbeiter besitzt einen einfachen Status.

## Available

Normale Verfügbarkeit.

Der Mitarbeiter erhält Calls und Requests.

## Pause

Der Mitarbeiter befindet sich in Pause.

In der Teamübersicht wird dies angezeigt.

Der Mitarbeiter nimmt nicht am normalen Routing teil.

## Busy

Der Mitarbeiter ist beschäftigt.

Er erhält:

- keine neuen Call-Notifications
- keine neuen Request-Notifications

Bereits aktive Aufgaben bleiben bestehen.

---

# 24. Teamübersicht

Unternehmen erhalten eine Übersicht aller Mitarbeiter, die aktuell im Dienst sind.

Angezeigt werden:

- Name
- Jobposition
- Status
- übernommene Hotlines

Beispiel:

```text
Dabi
Senior Driver
Available
Main Hotline, Airport

John
Driver
Busy
Main Hotline

Michael
Driver
Pause
-
```

---

# 25. Verteilung von Anrufen

Unternehmen können einstellen, wie Anrufe verteilt werden.

Die Einstellung kann unabhängig von Requests gesetzt werden.

Mögliche Modi:

```text
All
Random
Hotline only
```

---

# 26. Call Routing – All

Alle geeigneten Mitarbeiter erhalten die Anrufbenachrichtigung.

Wer zuerst annimmt, erhält den Anruf.

Danach verschwindet die Benachrichtigung bei den anderen Mitarbeitern.

---

# 27. Call Routing – Random

Der Server wählt zufällig einen geeigneten Mitarbeiter.

Nur dieser erhält die Anrufbenachrichtigung.

Nicht berücksichtigt werden:

- Mitarbeiter in Pause
- Mitarbeiter mit Status Busy
- Mitarbeiter außerhalb des Dienstes

Optional kann bei Nichtannahme ein anderer Mitarbeiter ausgewählt werden.

Dies sollte einfach umgesetzt werden und keine komplexe Warteschlange benötigen.

---

# 28. Call Routing – Hotline Only

Nur Mitarbeiter erhalten den Anruf, die die betreffende Telefonnummer beziehungsweise Hotline übernommen haben.

Beispiel:

```text
Incoming call:
Workshop Hotline
```

Nur Mitarbeiter mit:

```text
Workshop Hotline = active
```

werden berücksichtigt.

---

# 29. Request-Verteilung

Requests erhalten dieselben drei Routing-Modi.

```text
All
Random
Hotline only
```

Call Routing und Request Routing werden getrennt konfiguriert.

Beispiel:

```text
Call Routing:
Hotline only

Request Routing:
All
```

---

# 30. Request Routing – All

Alle geeigneten Mitarbeiter erhalten den Request.

Der erste Mitarbeiter, der den Request serverseitig erfolgreich annimmt, erhält ihn.

---

# 31. Request Routing – Random

Ein geeigneter Mitarbeiter wird zufällig ausgewählt.

Nur dieser erhält zunächst den Request.

---

# 32. Request Routing – Hotline Only

Nur Mitarbeiter mit einer passenden übernommenen Leitstelle erhalten den Request.

Dies ist besonders sinnvoll für Unternehmen mit mehreren Abteilungen.

---

# 33. Unternehmenseinstellungen

Unternehmensleiter erhalten einen kleinen Settings-Bereich.

Sie können innerhalb der vom Server-Admin gesetzten Grenzen konfigurieren:

- Telefonnummer aktiv/inaktiv
- Nachrichten aktiv/inaktiv
- Requests aktiv/inaktiv
- Postfach aktiv/inaktiv
- Call Routing
- Request Routing

Routing:

```text
All
Random
Hotline only
```

---

# 34. Admin-Vorgaben

Admin-Einstellungen haben immer Vorrang.

Beispiel:

```text
Admin:
Requests disabled
```

Dann kann das Unternehmen Requests nicht wieder aktivieren.

Oder:

```text
Admin:
Messaging allowed

Company:
Messaging disabled
```

Das Unternehmen darf die Funktion selbst deaktivieren.

---

# 35. Unternehmensaktivitäten

Der Unternehmensbereich enthält mehrere einfache Übersichten.

```text
Requests
Messages
Calls
Team
```

Diese können als Tabs oder kompakte Navigationspunkte umgesetzt werden.

---

# 36. Request-Übersicht

Mitarbeiter können sehen:

- aktive Requests
- vergangene Requests

Ein Request kann geöffnet werden.

Dabei werden Details angezeigt:

- Typ
- Nutzer
- Standort
- Personenanzahl
- Beschreibung
- Status
- zugewiesener Mitarbeiter

Vergangene Requests können aus der Ansicht entfernt werden.

---

# 37. Nachrichtenübersicht

Unternehmen sehen ihre Unterhaltungen.

Je nach Telefonnummer können separate Postfächer existieren.

Durch Klick wird das Gespräch geöffnet.

Das Verhalten soll sich möglichst stark an der nativen LB-Phone-Kommunikation orientieren.

---

# 38. Anrufübersicht

Unternehmen erhalten eine einfache Call-History.

Mögliche Zustände:

```text
Incoming
Answered
Missed
Declined
```

Ein Rückrufbutton ermöglicht einen direkten Rückruf.

---

# 39. Activity für normale Nutzer

Nutzer erhalten eine persönliche Aktivitätsübersicht.

Diese enthält:

- Nachrichten
- Requests
- Anrufe

Einträge können geöffnet werden.

Beispiele:

```text
Taxi Request
Completed

Police
Missed Call

Downtown Cab Co.
Message
```

---

# 40. Nutzeraktionen aus Activity

Je nach Eintrag können Nutzer:

- Gespräch öffnen
- Unternehmen erneut anrufen
- Requestdetails ansehen
- vergangene Einträge entfernen

Die Activity soll bewusst kompakt bleiben.

Keine komplexe CRM-Historie.

---

# 41. Nachrichten löschen

Nutzer können Nachrichten beziehungsweise Gespräche aus ihrer eigenen Ansicht entfernen.

Es sollte nach Möglichkeit kein unnötig komplexes globales Löschsystem entstehen.

Die Löschung kann als benutzerspezifisches Ausblenden beziehungsweise Archivieren umgesetzt werden.

---

# 42. Eigene Notifications

Services+ besitzt eigene interaktive Notifications.

Diese werden über die Sibling-NUI-Technik direkt in die LB-Phone-Oberfläche eingebunden.

Sibling-NUI wird ausschließlich dafür verwendet.

Die eigentliche App bleibt eine normale LB-Phone-Custom-App.

---

# 43. Request-Notification

Eine Request-Notification kann enthalten:

- Unternehmen
- Request-Typ
- eigenes Icon
- Standort
- Personenanzahl
- Beschreibung
- Accept
- Decline

Beispiel:

```text
TAXI REQUEST

Pickup required
2 passengers
Alta Street

[Decline] [Accept]
```

---

# 44. Notifications bei Phone Peek

Request-Notifications sollen auch sichtbar und bedienbar sein, wenn das Telefon nur im Peek-Zustand angezeigt wird.

Der Nutzer muss nicht zuerst Services+ öffnen.

---

# 45. Request annehmen

Bei Annahme:

1. Server prüft, ob der Request noch verfügbar ist.
2. Request wird dem Unternehmen beziehungsweise Mitarbeiter zugeordnet.
3. Andere Notifications werden entfernt.
4. GTA-Navigation wird aktiviert.
5. Request wird als aktiv angezeigt.

---

# 46. Native GTA-Navigation

Nach Annahme wird automatisch ein GTA-Waypoint zum Request-Standort gesetzt.

Kein eigenes Navigationssystem.

Keine eigene Karten-App.

---

# 47. Aktive Request-Anzeige

Nach Annahme kann die Notification in eine kompakte aktive Anzeige wechseln.

Diese enthält beispielsweise:

```text
Taxi Pickup

2 passengers
0.8 mi

[Complete]
```

Optional:

```text
Cancel
```

---

# 48. Maximale Request-Anzeige

Pro Mitarbeiter darf maximal eine aktive Request-Anzeige gleichzeitig sichtbar sein.

Dadurch werden:

- UI-Chaos
- Notification-Spam
- überlagerte Requests

vermieden.

Weitere Requests können weiterhin innerhalb der App sichtbar sein.

---

# 49. Sibling-NUI nur für Notifications

Sibling-NUI darf nicht zur Grundlage der gesamten App werden.

Verwendung ausschließlich für:

- Request-Notifications
- Accept/Decline
- aktive Request-Anzeige
- Phone-Peek-Integration

Dadurch bleibt die eigentliche App unabhängig und wartbar.

---

# 50. Adminbereich

Services+-Administratoren erhalten einen eigenen Bereich.

Dieser dient ausschließlich der Serverkonfiguration von Services+.

---

# 51. Unternehmen verwalten

Admins können:

- Unternehmen hinzufügen
- Unternehmen entfernen
- Unternehmen bearbeiten

Ein Unternehmen besitzt mindestens:

```text
Name
Framework Job
Category
Icon
Background Image
Main Phone Number
```

---

# 52. Telefonnummern verwalten

Admins können:

- Telefonnummer hinzufügen
- Telefonnummer entfernen
- Haupttelefonnummer definieren
- Postfach erlauben
- Calls erlauben
- Messages erlauben

Die Haupttelefonnummer kann nicht gelöscht werden.

---

# 53. Unternehmensfunktionen

Admins können für jedes Unternehmen erlauben oder deaktivieren:

```text
Calls
Messages
Requests
```

Diese Einstellungen stellen die maximale erlaubte Funktionalität dar.

---

# 54. Kategorien verwalten

Admins können Kategorien erstellen und bearbeiten.

Beispiele:

```text
Police
Medical
Taxi
Mechanic
Towing
Government
```

Eine Kategorie besitzt mindestens:

- Name
- Icon
- Sortierung
- Konkurrenz erlaubt

---

# 55. Request-Typen verwalten

Admins können Request-Typen definieren.

Beispiel:

```text
Taxi Pickup

Category: Taxi
Icon: taxi
Location: automatic
Passenger count: enabled
Description: optional
Competition: enabled
```

Dadurch bleiben Requests flexibel, ohne für jeden Server Sondercode zu benötigen.

---

# 56. Unternehmensleiter

Administratoren können einen Unternehmensleiter festlegen.

Wenn möglich, sollte dafür das vorhandene Job-/Grade-System des Frameworks verwendet werden.

Beispiel:

```text
ESX Job:
mechanic

Boss Grade:
4
```

Services+ soll keine zweite vollständige Mitarbeiterdatenbank neben dem Framework aufbauen.

---

# 57. Spieler-ID-Zuweisung

Optional kann der Admin einen aktuell verbundenen Spieler über seine Server-ID auswählen.

Beispiel:

```text
Player ID: 42
Make Company Leader
```

Services+ ermittelt den Spieler und setzt, sofern vom Framework unterstützt, den passenden Job beziehungsweise Boss-Grade.

Die dauerhafte Identität darf nicht ausschließlich auf der temporären Server-ID basieren.

---

# 58. Adminrechte

Services+-Adminrechte sollten unabhängig von Unternehmensrechten funktionieren.

Mögliche Quellen:

- ACE Permission
- Standalone Admin Config
- vorhandenes Framework-Adminsystem

Mindestens ACE Permissions sollten unterstützt werden.

---

# 59. Framework-Kompatibilität

Services+ besitzt nur eine kleine Framework-Adapter-Schicht.

Geplante Unterstützung:

```text
ESX
QBCore
Qbox
Standalone
```

---

# 60. Framework-Adapter

Der Adapter liefert ausschließlich die benötigten Informationen.

Beispielsweise:

```text
Player identity
Job
Job grade
Duty state
Boss permission
Set job / grade
```

Die eigentliche Services+-Logik bleibt framework-unabhängig.

---

# 61. Vorhandene Framework-Systeme verwenden

Services+ soll bestehende Systeme möglichst wiederverwenden.

Nicht neu bauen, wenn bereits vorhanden:

- Jobs
- Job Grades
- Duty
- Mitarbeiterzugehörigkeit
- Boss-Ränge
- Spieleridentität

Dadurch bleibt die Resource klein.

---

# 62. Serverautorität

Alle wichtigen Aktionen werden serverseitig geprüft.

Beispielsweise:

- Request annehmen
- Request abschließen
- Hotline übernehmen
- Unternehmenssettings ändern
- Telefonnummer ändern
- Unternehmen bearbeiten
- Nachrichten senden

Der Client darf keine Berechtigungen selbst bestimmen.

---

# 63. Performance-Ziel

Services+ soll für Server mit 600+ gleichzeitig verbundenen Spielern ausgelegt sein.

Das bedeutet insbesondere:

- keine dauerhaften schnellen Polling-Loops
- keine globalen Broadcasts für lokale Informationen
- keine vollständigen Datensynchronisierungen bei jeder Änderung
- keine unnötigen DB-Abfragen
- keine Standortübertragung ohne tatsächlichen Bedarf

---

# 64. Gezielte Events

Events werden nur an Spieler geschickt, die sie tatsächlich benötigen.

Beispiel:

Ein Taxi-Request geht nur an:

```text
aktuell im Dienst befindliche
geeignete
nicht beschäftigte
Taxi-Mitarbeiter
```

Nicht an alle 600 Spieler.

---

# 65. Mitarbeiterzustände im Speicher

Kurzlebige Zustände können serverseitig im Speicher gehalten werden.

Beispiele:

- aktuell im Dienst
- Busy/Pause
- übernommene Hotlines
- aktive Requests

Diese Daten müssen nicht bei jeder Aktion erneut aus der Datenbank geladen werden.

---

# 66. Persistente Daten

Dauerhafte Daten gehören in die Datenbank.

Beispiele:

- Unternehmen
- Telefonnummern
- Kategorien
- Request-Typen
- Nachrichten
- Request-Historie
- Einstellungen

---

# 67. Kein permanentes Standorttracking

Services+ trackt Spieler nicht dauerhaft.

Standorte werden nur übertragen, wenn sie benötigt werden.

Beispiele:

- Request erstellen
- Request annehmen
- Navigation setzen

Danach wird kein permanenter Standortstream benötigt.

---

# 68. Listen laden

Große Aktivitätslisten werden nicht vollständig auf einmal geladen.

Verwendung von Pagination für:

- Nachrichten
- Requests
- Calls
- Activity

Aktuelle Einträge können zuerst geladen werden.

Weitere Daten werden beim Scrollen nachgeladen.

---

# 69. Suche

Die Unternehmensliste ist vergleichsweise klein.

Die Liste kann einmal geladen und anschließend lokal durchsucht und nach Kategorien gefiltert werden.

Dadurch entstehen keine Serverrequests bei jedem Tastendruck.

---

# 70. Native Optik

Services+ soll sich visuell möglichst wenig wie eine externe Mod anfühlen.

Verwendung von:

- LB-Phone-artigen Abständen
- ähnlicher Typografie
- nativen Listendarstellungen
- nativen Buttons
- nativen Sheets/Popups
- Light/Dark Mode
- ähnlichen Animationen

Die App darf optisch erweitert werden, soll aber weiterhin klar wie ein Bestandteil des Telefons wirken.

---

# 71. Bewusst nicht enthalten

Services+ 1.0 enthält ausdrücklich kein:

- vollständiges CAD
- vollständiges Dispatch-System
- komplexes CRM
- komplexes Rollen-/ACL-System
- Skill Routing
- Prioritätsrouting
- Round-Robin-System
- eigene Navigation
- eigene Karten-App
- Bestellplattform
- Reservierungssystem
- permanentes GPS-Tracking
- umfangreiche Analytics
- riesiges automatisiertes Testsystem
- eigene Mitarbeiterverwaltung neben dem Framework
- Änderungen am LB-Phone-Core

---

# 72. Entwicklungsphase 1 – Basis

Ziel:

Services+ als funktionierende LB-Phone-App.

Umfang:

- Resource-Grundgerüst
- LB-Phone-Custom-App
- native UI
- Light/Dark Mode
- Framework-Adapter
- Unternehmensmodell
- Kategorien
- Unternehmensübersicht
- Suche
- Kategorie-Schnellfilter
- Unternehmensbilder
- Unternehmensicons
- Call-Integration
- Message-Integration
- mehrere Telefonnummern
- Telefonnummernauswahl
- Activity-Basis
- Company-Bereich
- Fake-Login

---

# 73. Entwicklungsphase 2 – Unternehmen & Requests

Ziel:

vollständige Gameplay-Funktionalität.

Umfang:

- Unternehmensdashboard
- Leitstellen
- mehrere Hotlines
- Hauptleitstellenregel
- Mitarbeiterstatus
- Teamübersicht
- Request-System
- Request-Typen
- automatische Standorte
- Personenanzahl
- optionale Beschreibung
- Konkurrenz-Requests
- Request-Historie
- Call-History
- Nachrichtenübersicht
- Routing:

```text
All
Random
Hotline only
```

für:

```text
Calls
Requests
```

- Unternehmenseinstellungen

---

# 74. Entwicklungsphase 3 – Notifications & Admin

Ziel:

fertige Services+ 1.0.

Umfang:

- Sibling-NUI-Controller
- Request-Notifications
- Phone-Peek-Unterstützung
- Accept
- Decline
- aktive Request-Anzeige
- maximal eine aktive Anzeige
- GTA-Waypoint
- Request abschließen
- Adminbereich
- Unternehmen erstellen
- Unternehmen entfernen
- Telefonnummern verwalten
- Kategorien verwalten
- Request-Typen verwalten
- Funktionen aktivieren/deaktivieren
- Konkurrenz konfigurieren
- Standard-Routing konfigurieren
- Unternehmensleiter festlegen
- Framework-Kompatibilität finalisieren

---

# 75. Entwicklungsprinzip

Services+ soll immer nach folgender Priorität entwickelt werden:

```text
Simple
↓
Native
↓
Fast
↓
Compatible
↓
Maintainable
```

Nicht:

```text
More features
↓
More abstraction
↓
More systems
↓
More complexity
```

Wenn eine Funktion mit einer kleinen direkten Lösung umgesetzt werden kann, wird diese einer großen abstrakten Architektur vorgezogen.

Services+ soll eine deutlich bessere Dienste-App für LB Phone werden und kein eigenständiges riesiges Unternehmensframework.
