# Mörderspiel – Setup-Anleitung

## 1. Flutter installieren

1. Gehe zu https://flutter.dev/docs/get-started/install/windows
2. Lade Flutter SDK herunter und entpacke es, z.B. nach `C:\flutter`
3. Füge `C:\flutter\bin` zu deinem PATH hinzu
4. Öffne ein neues Terminal und führe `flutter doctor` aus
5. Installiere fehlende Abhängigkeiten (Android Studio, Xcode für iOS)

## 2. Supabase-Projekt einrichten

1. Gehe zu https://supabase.com und erstelle ein kostenloses Konto
2. Erstelle ein neues Projekt
3. Gehe im Dashboard zu **SQL Editor**
4. Öffne `supabase/migrations/001_initial.sql` und führe den gesamten Inhalt aus
5. Gehe zu **Storage** → Erstelle einen neuen Bucket namens `avatars` (Public)
6. Gehe zu **Project Settings → API**
7. Kopiere die **Project URL** und den **anon public** Key

## 3. Supabase-Keys in die App eintragen

Öffne `lib/core/constants/app_constants.dart` und ersetze:

```dart
static const supabaseUrl = 'YOUR_SUPABASE_URL';       // deine Project URL
static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY'; // dein anon Key
```

## 4. App starten

```bash
cd C:\Users\FynnK\VSCode-Projects\moerderspiel

# Abhängigkeiten installieren
flutter pub get

# App starten (Android-Emulator oder echtes Gerät)
flutter run

# Für iOS (nur auf Mac mit Xcode)
flutter run -d ios
```

## 5. Für echte Geräte (Release-Build)

### Android APK
```bash
flutter build apk --release
# APK findet sich in: build/app/outputs/flutter-apk/app-release.apk
```

### iOS IPA (benötigt Mac + Apple Developer Account)
```bash
flutter build ipa --release
```

## Projektstruktur

```
lib/
├── main.dart                          # App-Einstiegspunkt
├── app.dart                           # MaterialApp + Router
├── core/
│   ├── constants/app_constants.dart   # ← Supabase-Keys hier eintragen!
│   ├── theme/app_theme.dart           # Dark/Light Theme
│   ├── router/app_router.dart         # Navigation
│   └── utils/helpers.dart
├── data/
│   ├── models/                        # Datenobjekte
│   └── repositories/                  # Supabase-Datenbankzugriffe
└── presentation/
    ├── providers/                     # Riverpod State Management
    ├── screens/                       # Alle Bildschirme
    └── widgets/                       # Wiederverwendbare UI-Komponenten

supabase/migrations/
└── 001_initial.sql                    # Datenbankschema (in Supabase ausführen)
```

## Spielablauf (Kurzübersicht)

1. **Spieler registrieren** sich mit E-Mail + Benutzername
2. **Admin erstellt** ein Spiel → erhält 6-stelligen Code
3. **Spieler treten bei** via Code
4. Alle markieren sich als **bereit**
5. Admin **startet das Spiel** → zufällige Zielzuweisung im Kreis
6. Jeder sieht nur **sein Ziel** + seine **Aufgaben**
7. Aufgabe erfüllen → **Kill melden** → Opfer muss **bestätigen**
8. Nach Bestätigung: Killer übernimmt **Ziel des Opfers** + alle **Aufgaben**
9. Letzter Überlebender **gewinnt** 🏆

## Technologie-Stack

| Schicht        | Technologie                    |
|----------------|-------------------------------|
| Frontend       | Flutter 3.x (iOS + Android)   |
| State Mgmt.    | Riverpod 2.x                  |
| Navigation     | go_router                     |
| Backend        | Supabase (Auth, DB, Realtime) |
| Datenbank      | PostgreSQL (via Supabase)     |
| Echtzeit       | Supabase Realtime Streams     |
| Datenschutz    | RLS-Richtlinien in Supabase   |
