// ignore_for_file: non_constant_identifier_names

import 'package:intl/intl.dart';

/// {"strict": Bool, "filter": List<[String]>}
typedef EntryFilter = Map<String, dynamic>;
typedef SubstitutionFilter = Map<String, EntryFilter>;

/// A data class to store a single substitution information
class Substitution {
  ///String of the format "dd.MM.yyyy"
  final String tag;

  ///String of the format "yyyy-MM-dd"
  final String tag_en;

  ///String of the format "1" or "1 - 2"
  final String stunde;
  final String? vertreter;
  final String? lehrer;
  final String? klasse;
  final String? klasse_alt;
  final String? fach;
  final String? fach_alt;
  final String? raum;
  final String? raum_alt;
  final String? hinweis;
  final String? hinweis2;
  final String? art;
  final String? Lehrerkuerzel;
  final String? Vertreterkuerzel;
  final dynamic lerngruppe;
  final List? hervorgehoben;

  Substitution(
      {required this.tag,
      required this.tag_en,
      required this.stunde,
      this.vertreter,
      this.lehrer,
      this.klasse,
      this.klasse_alt,
      this.fach,
      this.fach_alt,
      this.raum,
      this.raum_alt,
      this.hinweis,
      this.hinweis2,
      this.art,
      this.Lehrerkuerzel,
      this.Vertreterkuerzel,
      this.lerngruppe,
      this.hervorgehoben});

  bool passesFilter(SubstitutionFilter substitutionsFilter) {
    Map<String, Function> filterFunctions = {
      "Klasse": (filter) =>
          filterElement(klasse, filter["filter"], filter["strict"]),
      "Fach": (filter) =>
          filterElement(fach, filter["filter"], filter["strict"]),
      "Fach_alt": (filter) =>
          filterElement(fach_alt, filter["filter"], filter["strict"]),
      "Lehrer": (filter) =>
          filterElement(lehrer, filter["filter"], filter["strict"]),
      "Raum": (filter) =>
          filterElement(raum, filter["filter"], filter["strict"]),
      "Art": (filter) => filterElement(art, filter["filter"], filter["strict"]),
      "Hinweis": (filter) =>
          filterElement(hinweis, filter["filter"], filter["strict"]),
      "Vertreter": (filter) =>
          filterElement(vertreter, filter["filter"], filter["strict"]),
      "Stunde": (filter) =>
          filterElement(stunde, filter["filter"], filter["strict"]),
      "Lehrerkuerzel": (filter) =>
          filterElement(Lehrerkuerzel, filter["filter"], filter["strict"]),
      "Vertreterkuerzel": (filter) =>
          filterElement(Vertreterkuerzel, filter["filter"], filter["strict"]),
      "Klasse_alt": (filter) =>
          filterElement(klasse_alt, filter["filter"], filter["strict"]),
      "Raum_alt": (filter) =>
          filterElement(raum_alt, filter["filter"], filter["strict"]),
      "Hinweis2": (filter) =>
          filterElement(hinweis2, filter["filter"], filter["strict"]),
    };

    for (var key in substitutionsFilter.keys) {
      final filter = substitutionsFilter[key];
      if (filter == null ||
          filter["filter"] == null ||
          filter["filter"].isEmpty) {
        continue;
      }
      if (filterFunctions.containsKey(key) && !filterFunctions[key]!(filter)) {
        return false;
      }
    }
    return true;
  }

  ///returns true if the value contains all of the filter elements
  bool filterElement(String? value, List<String> filter, bool? strict) {
    if (value == null) {
      return false;
    }
    // remove all HTML tags from the value
    value = value.replaceAll(RegExp(r'<[^>]*>'), '');
    if (!(strict ?? true)) {
      return filter.any((element) => value!.contains(element));
    }
    for (var singleFilter in filter) {
      if (!value.contains(singleFilter)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'tag_en': tag_en,
        'stunde': stunde,
        'vertreter': vertreter,
        'lehrer': lehrer,
        'klasse': klasse,
        'klasse_alt': klasse_alt,
        'fach': fach,
        'fach_alt': fach_alt,
        'raum': raum,
        'raum_alt': raum_alt,
        'hinweis': hinweis,
        'hinweis2': hinweis2,
        'art': art,
        'Lehrerkuerzel': Lehrerkuerzel,
        'Vertreterkuerzel': Vertreterkuerzel,
        'lerngruppe': lerngruppe,
        'hervorgehoben': hervorgehoben,
      };

  Substitution.fromJson(Map<String, dynamic> json)
      : tag = json['tag'],
        tag_en = json['tag_en'],
        stunde = json['stunde'],
        vertreter = json['vertreter'],
        lehrer = json['lehrer'],
        klasse = json['klasse'],
        klasse_alt = json['klasse_alt'],
        fach = json['fach'],
        fach_alt = json['fach_alt'],
        raum = json['raum'],
        raum_alt = json['raum_alt'],
        hinweis = json['hinweis'],
        hinweis2 = json['hinweis2'],
        art = json['art'],
        Lehrerkuerzel = json['Lehrerkuerzel'],
        Vertreterkuerzel = json['Vertreterkuerzel'],
        lerngruppe = json['lerngruppe'],
        hervorgehoben = json['hervorgehoben'];
}

/// A data class to store all substitution information for a single day
class SubstitutionDay {
  // dd.MM.yyyy
  final String parsedDate;
  final List<Substitution> substitutions;
  final List<SubstitutionInfo>? infos;

  DateTime? _dateTime;

  DateTime get dateTime => getDateTime();

  DateTime getDateTime() {
    _dateTime ??= DateFormat('dd.MM.yyyy').parse(parsedDate);
    return _dateTime!;
  }

  SubstitutionDay(
      {required this.parsedDate, List<Substitution>? substitutions, this.infos})
      : substitutions = substitutions ?? [];

  void add(Substitution substitution) {
    substitutions.add(substitution);
  }

  void filterAll(SubstitutionFilter filter) {
    substitutions.removeWhere((element) => !element.passesFilter(filter));
  }

  Map<String, dynamic> toJson() => {
        'date': parsedDate,
        'substitutions': substitutions.map((s) => s.toJson()).toList(),
        'infos': infos?.map((i) => i.toJson()).toList(),
      };

  SubstitutionDay.fromJson(Map<String, dynamic> json)
      : parsedDate = json['date'],
        substitutions = (json['substitutions'] as List)
            .map((i) => Substitution.fromJson(i))
            .toList(),
        infos = (json['infos'] as List?)
            ?.map((i) => SubstitutionInfo.fromJson(i))
            .toList();

  SubstitutionDay withDayInfo(List<SubstitutionInfo> info) {
    return SubstitutionDay(
      parsedDate: parsedDate,
      substitutions: substitutions,
      infos: info.isNotEmpty ? info : null,
    );
  }
}

/// A data class to store all substitution information available
class SubstitutionPlan {
  final List<SubstitutionDay> days;
  DateTime lastUpdated;

  SubstitutionPlan({List<SubstitutionDay>? days, DateTime? lastUpdated})
      : days = days ?? [],
        lastUpdated = lastUpdated ?? DateTime.now();

  void add(SubstitutionDay substitutionDay) {
    days.add(substitutionDay);
  }

  List<Substitution> get allSubstitutions {
    List<Substitution> allSubs = [];
    for (var day in days) {
      allSubs.addAll(day.substitutions);
    }
    return allSubs;
  }

  void removeEmptyDays() {
    days.removeWhere((day) =>
        day.substitutions.isEmpty &&
        ((day.infos == null || day.infos!.isEmpty)));
  }

  void filterAll(SubstitutionFilter filter) {
    for (var day in days) {
      day.filterAll(filter);
    }
    removeEmptyDays();
  }

  Map<String, dynamic> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  SubstitutionPlan.fromJson(Map<String, dynamic> json)
      : days = (json['days'] as List)
            .map((i) => SubstitutionDay.fromJson(i))
            .toList(),
        lastUpdated = DateTime.parse(json['lastUpdated']);
}

/// A data class to store all information that is available to every user for a single substitution day
/// This value is plain html
class SubstitutionInfo {
  final String header;
  // List of html rows
  final List<String> values;

  SubstitutionInfo({required this.header, required this.values});

  Map<String, dynamic> toJson() => {
        'header': header,
        'values': values,
      };

  SubstitutionInfo.fromJson(Map<String, dynamic> json)
      : header = json['header'] as String,
        values =
            (json['values'] as List<dynamic>).map((e) => e as String).toList();
}
