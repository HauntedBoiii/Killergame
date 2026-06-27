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
