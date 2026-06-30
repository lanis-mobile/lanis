# Design: Lessons Features — Notenrechner, Alle Leistungen, Lehrer anschreiben

**Date:** 2026-06-30  
**Issues:** #508, #469, #464  
**Branch:** feature/new-features

---

## 1. Notenrechner (#508)

### Scope

Ein Notenrechner wird im bestehenden `CourseOverviewAnsicht` (Tab 1 „Leistungen") als zusätzliche UI eingebettet. Er berechnet den gewichteten Durchschnitt aus SPH-Noten und optional manuell eingetragenen Noten.

### Notenformat-Erkennung

- Jede Note (`LessonMark.mark`) wird automatisch klassifiziert:
  - Wenn der numerische Wert ≥ 7 → **Punkte-System** (0–15)
  - Sonst → **Notensystem 1–6** (inkl. `+`/`-`: z.B. `1+` = 0.67, `1` = 1.0, `1-` = 1.33)
- Noten die weder als 1–6 noch als 0–15 erkannt werden, werden ignoriert (angezeigt, aber nicht gerechnet)

### Kategorisierung & Gewichtung

- Jede Note (SPH + manuell) bekommt eine Kategorie: `mündlich`, `schriftlich`, `sonstig`
- Pro Kurs kann der Nutzer eine Gewichtung einstellen: z.B. 40% mündlich / 60% schriftlich
- Gewichtung und manuelle Noten werden lokal via `sph.prefs.kv` unter dem Schlüssel `grade-calc-<courseID>` gespeichert

### Berechnung

```
gewichteter_schnitt = (schnitt_mündlich * gewicht_mündlich + schnitt_schriftlich * gewicht_schriftlich) 
                      / (gewicht_mündlich + gewicht_schriftlich)
```

Wenn `sonstig`-Noten vorhanden: werden separat ausgewiesen, nicht gewichtet.

### UI

- Tab 1 (Leistungen) bekommt oben einen ausklappbaren „Notenrechner"-Bereich (Card)
- Zeigt: Kategorie-Chips pro Note (tippbar zum Wechseln), Gewichtungs-Schieberegler, Ergebnis
- Button „Note hinzufügen" öffnet Dialog: Name, Wert, Kategorie
- Manuelle Noten haben ein „×"-Icon zum Löschen

### Neue Dateien

- `lib/applets/lessons/student/grade_calculator.dart` — Widget + Berechnungslogik

---

## 2. Alle Leistungen auf einen Blick (#469)

### Scope

Neuer Screen der alle `DetailedLesson.marks` aus allen Kursen parallel lädt und in einer scrollbaren Liste anzeigt.

### Datenladen

- Einstiegspunkt: Neuer FAB-Button in `LessonsStudentView` (neben dem bestehenden Anwesenheiten-FAB)
- Beim Öffnen: `Future.wait()` über alle `Lesson`-Objekte, je ein `getDetailedCourseView()`-Call
- Während des Ladens: `CircularProgressIndicator` + Counter „X / Y Kurse geladen"
- Fehler bei einzelnen Kursen werden still ignoriert (Kurs wird übersprungen)

### UI

- `AllMarksScreen` — neuer StatefulWidget
- Expandable Cards pro Kurs (default: zugeklappt)
- Jede Card zeigt: Kursname, Lehrer-Kürzel, Notenanzahl, beim Aufklappen: Notenliste
- Kurse ohne Noten werden nicht angezeigt

### Neue Dateien

- `lib/applets/lessons/student/all_marks_screen.dart`

---

## 3. Lehrer anschreiben aus Lessons (#464)

### Scope

Aus `CourseOverviewAnsicht` heraus kann der Nutzer direkt einen Chat mit dem/den Lehrer(n) des Kurses starten.

### UI-Einstiegspunkt

- Neuer Button in der AppBar von `CourseOverviewAnsicht` (Briefumschlag-Icon)
- Nur sichtbar wenn `conversationsParser` verfügbar und Kurs mindestens einen Lehrer hat

### Ablauf

1. Nutzer tippt auf Button
2. App ruft `conversationsParser.searchTeacher(teacherName)` für jeden Lehrer auf
3. Wenn genau 1 Treffer → direkt in Pre-filled `NewConversationConfigurator` mit Empfänger vorbelegt
4. Wenn 0 oder mehrere Treffer → Dialog mit Auswahl / Fehlermeldung
5. `NewConversationConfigurator` wird wie bisher über `Navigator.push` geöffnet

### Einschränkung

`LessonTeacher.teacher` enthält nur den Anzeigenamen (z.B. „Max Mustermann"), nicht die Nachrichten-ID. `searchTeacher()` sucht per Name und gibt `ReceiverEntry` (mit ID) zurück. Bei Namenskollisionen muss der Nutzer manuell auswählen.

### Keine neuen Dateien nötig

Änderungen nur in `course_overview.dart`.

---

## Abhängigkeiten zwischen Features

- Feature 1 und 3 sind unabhängig voneinander implementierbar.
- Feature 2 hängt von `getDetailedCourseView()` ab (bereits vorhanden).
- Reihenfolge der Implementierung: **3 → 2 → 1** (aufsteigender Aufwand).
