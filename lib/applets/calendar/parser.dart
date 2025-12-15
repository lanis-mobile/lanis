import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:lanis/models/calendar_event.dart';

import '../../core/applet_parser.dart';
import '../../core/connection_checker.dart';
import '../../models/client_status_exceptions.dart';

class CalendarParser extends AppletParser<List<CalendarEvent>> {
  CalendarParser(super.sph, super.appletDefinition);

  @override
  Future<List<CalendarEvent>> getHome() async {
    return getCalendar(
        startDate: DateTime.now().subtract(Duration(days: 120)),
        endDate: DateTime.now().add(Duration(days: 356)));
  }

  Future<List<CalendarEvent>> getCalendar(
      {required DateTime startDate,
      required DateTime endDate,
      String searchQuery = ''}) async {
    final formatter = DateFormat('yyyy-MM-dd');

    try {
      List<CalendarEventCategory> categories = [];

      final docResponse = await sph.session.dio
          .get("https://start.schulportal.hessen.de/kalender.php");
      final lines = docResponse.data
          .split("var categories = new Array();")[1]
          .split("var groups = new Array();")[0]
          .split("\n");
      for (String line in lines) {
        final match = RegExp(r"\{.*\}").firstMatch(line);
        if (match == null) continue;
        String trueJson = match
            .group(0)!
            .replaceAllMapped(RegExp(r"(\w+):"), (m) => "\"${m[1]}\":")
            .replaceAll("'", '"');
        final category = jsonDecode(trueJson);
        final color = Color(
            int.parse(category['color'].substring(1, 7), radix: 16) +
                0xFF000000);
        categories.add(
          CalendarEventCategory(
              id: category['id'], color: color, name: category['name']),
        );
      }

      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/kalender.php",
              queryParameters: {
                "f": "getEvents",
                "s": searchQuery,
                "start": formatter.format(startDate),
                "end": formatter.format(endDate),
              },
              data: 'f=getEvents&start=$startDate&end=$endDate&s=$searchQuery',
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                },
              ));
      final data = jsonDecode(response.data);
      List<CalendarEvent> finalData = [];
      for (int i = 0; i < (data as List<dynamic>).length; i++) {
        finalData.add(CalendarEvent.fromLanisJson(data[i], categories));
      }

      return finalData;
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  Future<Map<String, dynamic>?> getEvent(String id) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/kalender.php",
              data: {
                "f": "getEvent",
                "id": id,
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                },
              ));
      final data = jsonDecode(response.toString());
      if (data['id'] == '' || data['id'] == null) return null;

      return data;
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  Future<({Set<int> years, String subscriptionLink})> getExports() async {
    final response = await sph.session.dio
        .get("https://start.schulportal.hessen.de/kalender.php");

    final Set<int> years = {};

    final regex = RegExp(r"year=(\d\d\d\d)");
    final matches = regex.allMatches(response.data);
    for (var match in matches) {
      years.add(int.parse(match.group(1)!));
    }

    final iCalSubLink = await sph.session.dio.post(
        "https://start.schulportal.hessen.de/kalender.php",
        data: {
          "f": "iCalAbo",
        },
        options: Options(
          headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
          },
        ));

    return (years: years, subscriptionLink: iCalSubLink.data as String);
  }
}
