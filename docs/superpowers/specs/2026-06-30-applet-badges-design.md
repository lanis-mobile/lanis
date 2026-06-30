# Badges für Applet-Icons (Issue #497)

## Ziel

Das `info`-Feld aus dem Lanis Fast-Travel-Menu (`startseite.php?a=ajax&f=apps`) auslesen und als Badge-Zähler auf den Applet-Icons in NavigationBar und NavigationDrawer anzeigen.

## Datenfluss

- `SessionHandler.getFastTravelMenu()` liefert ein JSON-Array mit Einträgen der Form `{"link": "nachrichten.php", "info": "3", ...}`.
- Das `info`-Feld wird beim Parsen in `Map<String, int> appletBadges` umgewandelt (Key = `link`, Value = Integer-Count). Leere oder fehlende `info`-Felder ergeben keinen Eintrag.
- Die Map wird in `SessionHandler` gespeichert und bei jedem `authenticate()`-Call aktualisiert.

## UI

- **NavigationDestination** (Bottom Nav): Icon wird bei `count > 0` in ein Flutter `Badge`-Widget gewickelt. Werte > 9 werden als `"9+"` dargestellt.
- **NavigationDrawerDestination**: analog.
- Kein eigener Polling-Loop — Badges aktualisieren sich beim App-Start / Re-Authenticate.

## Betroffene Dateien

- `lib/core/sph/session.dart` — `appletBadges` Map + Parsing in `getFastTravelMenu()`
- `lib/home_page.dart` — Badge-Wrapping in `navBar()` und `navDrawer()`
