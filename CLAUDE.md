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
