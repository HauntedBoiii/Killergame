# Mörderspiel – Projekt-Kontext für Claude

## Was ist das?
Multiplayer-Assassinen-Partyspiel als Flutter Web PWA. Spieler bekommen Würfelaufgaben (Kniffel-Style) und müssen sich gegenseitig "eliminieren". Läuft komplett im Browser.

## Tech-Stack
- **Frontend:** Flutter 3.x + Riverpod 2.x, Google Fonts (Rajdhani als Hauptfont)
- **Backend:** Supabase — PostgreSQL mit RLS, SECURITY DEFINER Functions, Realtime
- **Deployment:** Netlify (git push auf main → Auto-Build)
- **Push:** VAPID Web Push, eigener Service Worker (`web/push-sw.js`), iOS 16.4+ PWA

## Wichtige Dateipfade
```
lib/presentation/screens/        – alle Produktions-Screens
lib/core/services/               – Services (inkl. Push)
supabase/schema.sql              – VOLLSTÄNDIGES DB-Schema (nach jeder SQL-Änderung aktuell halten!)
supabase/migrations/             – chronologische Migrationen (aktuellste: 011)
supabase/functions/send-push/    – Edge Function für Push Notifications
web/push.js                      – JS-seitige SW-Registrierung & Subscription
web/push-sw.js                   – Service Worker (Push-Handler, eigener Scope!)
lib/core/services/push_notification_service.dart
```

## Regeln & Eigenheiten

### SQL
- Änderungen **immer doppelt**: im Supabase SQL Editor ausführen UND in `supabase/schema.sql` nachpflegen.
- `supabase/schema.sql` enthält Platzhalter `<project-ref>` und `<service_role_key>` im DB-Trigger – das ist Absicht, nie ersetzen.
- Migrationen liegen unter `supabase/migrations/` und sind nummeriert (001, 002, …). Neue Migrationen fortlaufend nummerieren.

### Deployment
- Netlify-Builds sind limitiert → Flutter/Web-Änderungen **bündeln**, nie für eine Kleinigkeit einzeln pushen.
- Edge Functions sind direkt im Supabase Dashboard bearbeitbar (kein Build nötig).

### Push Notifications
- Flutter registriert seinen eigenen Service Worker bei `/` (Scope).
- `push-sw.js` läuft bei `/push-notifications/` (anderem Scope) – diese Trennung ist zwingend, nicht zusammenführen.
- Push-Subscriptions stehen in Tabelle `push_subscriptions` – braucht GRANT für `authenticated` UND `service_role`.

### Sicherheit
- API-Keys, Tokens und Secrets **niemals im Chat** – nur direkt in Config-Dateien eintragen.

## Design-Konventionen & UI-Prinzipien

### Farbsystem
Nur vier semantische Farben — keine Ad-hoc-Farben wie `Colors.blue`, `Colors.teal`, `Colors.purple`, `Colors.orange` in der UI verwenden.

| Farbe | Verwendung |
|---|---|
| **Crimson** `#B71C1C` (`theme.colorScheme.primary`) | Primäre CTAs, aktive Zustände, Akzent-Borders |
| **Amber** `Colors.amber` | Warnung, ausstehend (Pending-States) |
| **Green** `Colors.green` | Erfolg, Bestätigung |
| **Grey** `Colors.grey` | Passive Icons, Labels, De-emphasis, Info-Zustände |

Danger-Zonen dürfen `Colors.red` verwenden (explizite Destruktions-Aktionen). Status-Cards im Admin-Bereich dürfen dynamische `statusColor` (green/orange/red) nutzen — das ist semantisch, kein Ad-hoc-Einsatz.

### Border-Radius-System
- `12` — kleine Karten, Chips, Icon-Container, Dialog-interne Elemente
- `16` — Standard-Cards, Einstellungskarten
- `20` — Hero-Cards (prominent, large)

Konsistenz geht vor: lieber ein Radius zu wenig variieren als zu viele.

### Typografie
- **Rajdhani** — Überschriften (`titleLarge`, `displayLarge`, `AppBar`)
- **Inter** — Fließtext, Labels, Subtitles
- Keine eigenen `fontFamily`-Overrides in Widgets — Theme nutzen.

### Tap-Feedback (Ripple)
Nie `GestureDetector` für tappable Cards — immer `Ink + Material(transparency) + InkWell`:

```dart
Ink(
  decoration: BoxDecoration(...),
  child: Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(...),
    ),
  ),
)
```

`BoxShadow` mit sehr niedrigem Alpha (`0.1`) weglassen — imperceptible und erhöht Komplexität.

### Shared Button-Komponente
Immer `AppButton` (`lib/presentation/widgets/common/app_button.dart`) verwenden:
- `outlined: true` + `color:` für sekundäre/destruktive Outlined-Buttons
- `color:` für farbige Filled-Buttons
- `isLoading:` für Lade-Zustände
- `icon:` für Icon + Label

Nie rohe `ElevatedButton`, `OutlinedButton` oder `TextButton.icon` in Screens verwenden.

### Settings-UI-Pattern
Für Einstellungsbereiche (create_game_screen, admin_screen) gelten zwei private Widget-Klassen:

**`_SettingsCard`** — Container mit Icon+Label-Header und optionalem `trailing`-Widget (z.B. Add-Button):
- Border: `iconColor.withValues(alpha: 0.25)`
- Border-Radius: `16`
- `iconColor` immer `Colors.grey` (kein semantischer Farbcode für reine UI-Struktur)

**`_SettingsTile`** — Zeile innerhalb einer `_SettingsCard` mit Icon-Container, Titel/Subtitle und trailing Widget (Switch, etc.):
- Icon-Container: `iconColor.withValues(alpha: 0.12)` Hintergrund, Radius `8`
- Padding: `symmetric(horizontal: 16, vertical: 12)` (create_game) / `symmetric(vertical: 12)` (admin, da Container padding übernimmt)
- `Divider(height: 1)` zwischen Tiles

Diese Klassen sind file-privat (`_`) und existieren in beiden Screens — kein shared Import. Nur konsolidieren wenn ein dritter Nutzer entsteht.

### Deprecated APIs vermeiden
- Immer `.withValues(alpha: x)` statt `.withOpacity(x)`
- Kein `DropdownButtonFormField(value:)` → `initialValue:` nutzen

---

## Feature-Vorschläge (noch nicht implementiert)

### Schicksalskarten
Tägliche optionale Karten-Zieh-Mechanik. Spieler können jeden Tag eine verdeckte Karte aufdecken — müssen aber nicht. Erzeugt tägliche Wiederkehr wie Kniffel, passt thematisch zum düsteren Assassinen-Universum.

**Verteilung:** ~55% gute Karten, ~45% schlechte Karten — nah genug an 50/50, damit das Zögern real ist.

**Gute Karten:**
- Blutgold — +1 Bronzecredit (sofort)
- Silberne Gnade — +1 Silvercredit (sofort)
- Schutzmantel — 2h Schutz, frei einlösbar (Token)
- Zusatzauftrag — heute eine weitere Aufgabe (sofort)
- Glückswurf — beim heutigen Kniffel ein Feld doppelt streichen (Kniffel)
- Narrenzug — beim heutigen Kniffel einen vierten Wurf in einer Runde (Kniffel)
- Spurlos — Jäger sieht heute nur "???" statt deinem Namen (24h)
- Blutiger Bonus — nächster Kill zählt doppelt für Credits (Token)
- Informant — du erfährst wie viele Kills dein Ziel hat (sofort)
- Freie Hand — nächster Kill ohne Admin-Bestätigung (Token)
- Zweite Chance — aktuelle Aufgabe kostenlos tauschen (Token)
- Lootbox-Fund — +1 Bronze-Lootbox (sofort)

**Schlechte Karten:**
- Würfelgrab — Kniffel-Feld "Kniffel" heute automatisch gestrichen (Kniffel)
- Geächteter — 24h ohne Zeugen und in Schutzzonen eliminierbar (24h)
- Schwarze Hand — aktiver Schutzmantel wird sofort aufgehoben (sofort)
- Verfluchter Wurf — beim heutigen Kniffel nur zwei Würfe pro Runde (Kniffel)
- Fehlinformation — 24h falscher Zielname sichtbar (24h)
- Tributpflicht — -1 Bronzecredit (min. 0, sofort)
- Vergifteter Auftrag — aktuelle Aufgabe wird durch Schwierigkeit-3-Aufgabe ersetzt (sofort)
- Stumme Klinge — 6h keine Kills melden (6h)
- Schlechtes Omen — falls heute eliminiert: -2 Credits extra (24h)
- Verhext — nächster Kill braucht Zeugen, auch ohne Admin-Bestätigung (Token)

**DB-Skizze:** `fate_card_draws(id, user_id, drawn_at, card_type, effect_expires_at, redeemed_at, is_active)`

**Integrationspoints:** Kill-Reporting (Geächteter, Stumme Klinge, Freie Hand, Verhext), Kniffel (Würfelgrab, Glückswurf, Narrenzug, Verfluchter Wurf), Home-Screen (Card-Widget analog zu _DailyKniffelCard)

**Offene Fragen vor Implementierung:**
- Karte ablehnen nach dem Aufdecken oder Ziehen = Annehmen?
- Stapeln sich Flüche über mehrere Tage?
- Sehen andere Spieler aktive Flüche (Badge auf Profilkarte)?
- Seltenheitsstufen (Common/Rare) mit stärkeren Effekten?

### Codewort / Doppelagent (Spyfall-Mechanik)
Mini-Spiel das separat vom laufenden Assassinen-Spiel gestartet werden kann. Passt thematisch perfekt: alle sind Agenten, einer ist ein Doppelagent der das Codewort nicht kennt.

**Kern-Mechanik:**
- Alle Spieler außer einem sehen dasselbe geheime Codewort (z.B. "Leuchtturm")
- Der Doppelagent sieht nur: "Du bist der Doppelagent" — kein Wort
- In zufälliger Reihenfolge sagt jeder Spieler pro Runde **einen einzigen Begriff** der zum Codewort passt — nicht zu offensichtlich (sonst errät der Doppelagent), aber gut genug dass die Gruppe ihn versteht
- Nach jeder Runde: optionale Abstimmung wer der Doppelagent ist
- Der Doppelagent kann jederzeit raten: nennt er das Codewort korrekt, gewinnt er sofort

**Siegbedingungen:**
- Gruppe wählt den Doppelagenten raus → Gruppe gewinnt
- Doppelagent nennt das Codewort korrekt (auch nach dem Rauswurf) → Doppelagent gewinnt
- Doppelagent überlebt X Runden unentdeckt → Doppelagent gewinnt

**Zwei Modi:**

*Full Online-Modus*
- Codewort wird allen normalen Spielern in der App angezeigt
- Begriffe werden in einen In-App-Chat getippt (Reihenfolge erzwungen — nächster Spieler kann erst eingeben wenn der vorherige dran war)
- Abstimmung und Auflösung komplett in der App
- Asynchron spielbar, kein gemeinsamer Raum nötig

*Hybrid-Modus*
- App zeigt das Codewort (normalen Spielern) und die Spielreihenfolge
- Begriffe werden laut im Raum gesagt — App trackt nur Reihenfolge und Timer
- App übernimmt: Abstimmung, Doppelagent-Auflösung, Codewort-Rateversuch
- Ideal für physische Spielrunden wo Mörderspiel eh schon gespielt wird

**DB-Skizze:**
- `codename_sessions(id, host_id, game_id nullable, codword, status, mode, created_at)`
- `codename_players(id, session_id, user_id, is_impostor, clues_given[])`
- `codename_clues(id, session_id, player_id, round, clue_text, submitted_at)` — nur Full Online
- `codename_votes(id, session_id, voter_id, voted_for_id, round)`

**Mindestspielerzahl:** 7 Spieler — darunter kein Start möglich.

**Belohnungen:**
- Doppelagent gewinnt → 1 Lootbox
- Gruppe gewinnt → Credits (Betrag noch offen)

**Integrationspoints:**
- Vom Home-Screen oder aus einer aktiven Spiellobby startbar
- Codewort-Pool: vordefinierte thematische Wörter (Agenten/Thriller-Thema: "Bunker", "Akte", "Verräter", "Schalldämpfer" etc.) + erweiterbar

**Offene Fragen vor Implementierung:**
- Feste Rundenanzahl oder bis zur Abstimmung?
- Mehrere Doppelагенты möglich (ab X Spielern)?
- Codewort-Kategorien wählbar (z.B. "Orte", "Agenten-Ausrüstung", "Personen")?
- Timer pro Zug im Full-Online-Modus?

### Schnick-Schnack-Schnuck-Turnier
Spontanes KO-Turnier unter allen aktiven Spielern eines laufenden Spiels. Belohnung: eine zweite Chance beim heutigen Daily-Kniffel — es zählt am Ende nur die bessere der zwei Runden.

**Ablauf:**
- Admin oder Spieler startet ein Turnier (einmal pro Tag?)
- Alle aktiven Spieler werden automatisch eingelost
- KO-Bracket: je zwei Spieler spielen gegeneinander, Sieger kommt weiter
- Jedes Duell: gleichzeitige Eingabe (Schere/Stein/Papier), bei Unentschieden Wiederholung
- Finale → Sieger bekommt zweite Kniffel-Runde

**Technische Skizze:**
- `rps_tournaments(id, game_id, created_at, status, bracket_json)`
- `rps_matches(id, tournament_id, player_a, player_b, choice_a, choice_b, winner, round)`
- Realtime: beide Spieler sehen live wenn Gegner gewählt hat → Reveal
- Zeitlimit pro Zug (z.B. 30s), bei Timeout zufällige Wahl

**Offene Fragen vor Implementierung:**
- Wer kann ein Turnier starten — nur Admin oder jeder Spieler?
- Mindestspielerzahl (sinnvoll ab 4)?
- Was passiert bei ungerade Spielerzahl (Freilos)?
- Zweite Kniffel-Runde: neue komplette Runde oder nur einzelne Felder nachspielen?

---

## Design-Vorschau (standalone, kein Produktionscode)
Es gibt eine separate Vorschau-App für UI-Designs:
```
lib/main_design_preview.dart
```
Starten mit:
```
flutter run -t lib/main_design_preview.dart -d edge
```
Diese Datei wird **nicht** mit der Produktions-App deployed und ist nur zum Vergleichen von Designs gedacht. Nicht in `main.dart` oder andere Produktionsdateien importieren.

### Aktueller Stand der Designs (nach 3 Feedback-Runden)
**Profilkarte (Tab 1):** CURRENT (Referenz), #1 Glas+Shimmer, #2 Neon-Rand, #3 Bond 007, #4 Funken+Ambient, #7 Dark Smoke, #8 Steckbrief/WANTED-Poster, #10 Farbwechsel-Akzent

**Würfel (Tab 2):** CURRENT, W1 Holz, W2 Neon, W4 Vegas, W5 Blut, W6 App-Rot, W7 Digital (7-Segment), W9 Kristall+Risse

## Datenbankfunktionen – was `start_game` tut
Die Funktion `public.start_game(game_id_param uuid)` (Migration 011):
1. Prüft Admin-Berechtigung des aufrufenden Users
2. Wählt Tasks aus dem Admin-Pool (ohne deaktivierte)
3. Sortiert nach Schwierigkeit (1+2 vor 3), dann random
4. Verteilt Tasks an alle Spieler
5. Erstellt den **Assignment-Ring**: Spieler 1 → 2 → 3 → … → N → 1 (jeder hat genau ein Ziel)
6. Setzt `games.status = 'active'`
