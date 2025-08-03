import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:lanis/core/applet_parser.dart';

import '../../../models/lessons_teacher.dart';
import '../../../utils/logger.dart';
import '../../substitutions/parser.dart';

class LessonsTeacherParser extends AppletParser<LessonsTeacherHome> {
  LessonsTeacherParser(super.sph, super.appletDefinition);

  @override
  Future<LessonsTeacherHome> getHome() async {
    final response = await sph.session.dio
        .get('https://start.schulportal.hessen.de/meinunterricht.php?jump=no');
    final Document document = parse(response.data);
    final Element? courseFoldersElement = document.getElementById('hefte');
    if (courseFoldersElement == null) {
      throw Exception('Could not find course folders');
    }
    final List<CourseFolderStartPage> courseFolders = [];
    for (final Element courseFolderElement in courseFoldersElement.children) {
      final String url = courseFolderElement
          .querySelector('div.thumbnail>div.caption>h3>a')!
          .attributes['href']!;
      final String title = courseFolderElement
          .querySelector('div.thumbnail>div.caption>h3')!
          .text
          .trim();
      final List<Element> tableRows =
          courseFolderElement.querySelector('div.thumbnail>div.row')!.children;
      final String courseTopic = tableRows[0].text.trim();
      final String lastEntryTopic = tableRows[1].text.trim();
      final String lastEntryDate = tableRows[2].text.trim();
      final String homework = courseFolderElement
              .querySelector('div.thumbnail>p>span.homework')
              ?.text
              .trim() ??
          '';

      // parse format dd.mm.yyyy
      final DateTime? lastEntryDateTime = lastEntryDate.isNotEmpty
          ? DateFormat('dd.MM.yyyy').tryParse(lastEntryDate)
          : null;

      courseFolders.add(CourseFolderStartPage(
          id: RegExp(r'id=(\d+)').firstMatch(url)!.group(1)!,
          name: title,
          topic: courseTopic,
          entryInformation: lastEntryTopic != ''
              ? CourseFolderStartPageEntryInformation(
                  topic: lastEntryTopic,
                  date: lastEntryDateTime!,
                  homework: homework != ''
                      ? (homework != 'Keine Hausaufgaben hinterlegt!'
                          ? homework
                          : null)
                      : null)
              : null));
    }

    return LessonsTeacherHome(courseFolders: courseFolders);
  }

  Future<CourseFolderDetails> getCourseFolderDetails(String courseId) async {
    final response = await sph.session.dio.get(
        'https://start.schulportal.hessen.de/meinunterricht.php?a=view&id=$courseId');
    final Document document = parse(response.data);

    List<CourseFolderHistoryEntry> history = [];
    final historyTable = document.getElementById('historyTable');
    for (Element entryRow in historyTable?.children[1].children ?? []) {
      // extract dd.MM.yyyy via regex from entryRow.children[0].text
      final String dateStr = RegExp(r'(\d{2}\.\d{2}\.\d{4})')
              .firstMatch(entryRow.children[0].text)
              ?.group(1) ??
          '';

      final contentResults =
          entryRow.children[2].getElementsByClassName('far fa-comment-alt');
      final homeworkResults =
          entryRow.children[2].getElementsByClassName('fas fa-home');

      List<CourseFolderHistoryEntryFile> remoteFiles = [];
      for (final fileDiv in entryRow.getElementsByClassName('file')) {
        final fileName = fileDiv.attributes['data-file']!;
        final fileId = fileDiv.attributes['data-entry']!;
        final url =
            'https://start.schulportal.hessen.de/meinunterricht.php?a=downloadFile&id=$courseId&e=$fileId&f=$fileName';
        remoteFiles.add(CourseFolderHistoryEntryFile(
          name: fileName,
          extension: fileDiv.attributes['data-extension']!,
          isVisibleForStudents: fileDiv
              .getElementsByClassName('fa fa-child fileVisibility')[0]
              .classes
              .contains('on'),
          url: Uri.parse(url),
          entryId: fileId,
        ));
      }

      history.add(CourseFolderHistoryEntry(
        id: entryRow.attributes['data-entry']!,
        topic: entryRow.getElementsByClassName('thema')[0].text.trim(),
        date: DateFormat('dd.MM.yyyy').parse(dateStr),
        schoolHours: SubstitutionsParser.parseHours(
            entryRow.children[0].getElementsByTagName('small')[0].text.trim()),
        isAvailableInAdvance:
            entryRow.children[0].querySelector('i.fa.fa-child') != null,
        files: remoteFiles,
        attendanceActionRequired: entryRow.children[3]
            .querySelectorAll('div.btn-group')
            .last
            .children[0]
            .classes
            .contains('btn-danger'),
        content: contentResults.isNotEmpty
            ? contentResults[0].nextElementSibling?.text
            : null,
        homework: homeworkResults.isNotEmpty
            ? homeworkResults[0].nextElementSibling?.text
            : null,
        studentUploadFileCount: entryRow.children[3]
            .querySelectorAll('div.btn-group')[1]
            .querySelector('button.btn>span.badge')
            ?.text,
      ));
    }

    Element? countAndNameElement = document.querySelector('#content>h1>small');
    String text = countAndNameElement?.text.trim() ?? '';

    final writeBox = document.getElementById('writeBox')!;
    final entryOptionIcons = writeBox.querySelectorAll(
        'div.form-group>label.col-sm-3.control-label>span.fa');
    List<String> selectableSchoolHours = document
        .getElementById('stundenVon')!
        .children
        .map((e) => e.text)
        .toList();
    selectableSchoolHours = selectableSchoolHours
        .where((elem) => elem != '')
        .toList(growable: false);

    return CourseFolderDetails(
      courseId: courseId,
      newEntryConstraints: CourseFolderNewEntryConstraints(
        topicVisibleForStudents:
            entryOptionIcons[2].classes.contains('fa-child'),
        contentVisibleForStudents:
            entryOptionIcons[3].classes.contains('fa-child'),
        homeworkVisibleForStudents:
            entryOptionIcons[4].classes.contains('fa-child'),
        schoolHours: selectableSchoolHours,
      ),
      courseName:
          document.getElementsByTagName('title')[0].text.split('-')[0].trim(),
      studentCount: int.parse(text.trim().split('-')[0].trim()),
      learningGroupsUrl: Uri.tryParse(
          document.querySelector('#content>h1>small>a')?.attributes['href'] ??
              ''),
      courseTopic: (document
                  .querySelector('#content>h1')
                  ?.children
                  .last
                  .text
                  .trim()
                  .replaceFirst('Thema:', '') ??
              '')
          .trim(),
      history: history,
    );
  }

  Future<bool> postNewEntry({
    /// Course ID
    required String book,

    /// dd.MM.yyyy
    required String datum,
    required bool zeigeauchvorheran,
    required String stundenVon,
    required String stundenBis,
    required String subject,
    required String inhalt,
    required String homework,
    required bool abgabe,
    required DateTime abgabeBisDate,
    required TimeOfDay abgabeBisTime,
    required bool abgabeSichtbar,
  }) async {
    final DateTime abgabeDateTime = DateTime(
      abgabeBisDate.year,
      abgabeBisDate.month,
      abgabeBisDate.day,
      abgabeBisTime.hour,
      abgabeBisTime.minute,
      0,
    );
    final data = {
      'a': 'newBookEntry',
      'book': book,
      'datum': datum,
      if (zeigeauchvorheran) 'zeigeauchvorheran': 'ja',
      'stundenVon': stundenVon,
      'stundenBis': stundenBis,
      'subject': subject,
      'inhalt': inhalt,
      'homework': homework,
      'abgabe': abgabe ? '1' : '0',
      'abgabeBisDate': DateFormat('dd.MM.yyyy').format(abgabeDateTime),
      'abgabeBisTime': DateFormat('HH:mm').format(abgabeDateTime),
      'abgabeBis': DateFormat('yyyy-MM-dd HH:mm:ss').format(abgabeDateTime),
      'abgabeSichtbar': abgabeSichtbar ? "Alle" : "Lehrende",
    };

    try {
      final response = await sph.session.dio.post(
        "https://start.schulportal.hessen.de/meinunterricht.php",
        data: data,
        options: Options(
          contentType: "application/x-www-form-urlencoded; charset=UTF-8",
          headers: {
            "Accept": "*/*",
            "Accept-Encoding": "gzip, deflate, br, zstd",
            "Accept-Language": "en-US,en;q=0.5",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Content-Length": "296",
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "Host": "start.schulportal.hessen.de",
            "Origin": "https://start.schulportal.hessen.de",
            "Pragma": "no-cache",
            "Priority": "u=0",
            "Referer":
                "https://start.schulportal.hessen.de/meinunterricht.php?a=view&id=3",
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Mode": "no-cors",
            "Sec-Fetch-Site": "same-origin",
            "User-Agent":
                "Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0",
            "X-Requested-With": "XMLHttpRequest"
          },
        ),
      );

      jsonDecode(response.data);
      return true;
    } catch (e) {
      logger.e(e);
      return false;
    }
  }

  // Fragile request, do not touch!
  Future<bool> deleteEntry(String courseId, String entryId) async {
    final data = {
      'a': 'deleteBookEntry',
      'b': courseId,
      'e': entryId,
      'pw': sph.session.cryptor.encryptString(sph.account.password),
    };

    // password has to be encoded correctly, du to special characters
    final encodedData = data.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final response = await sph.session.dio.post(
      "https://start.schulportal.hessen.de/meinunterricht.php",
      data: encodedData,
      options: Options(
        contentType: "application/x-www-form-urlencoded; charset=UTF-8",
        headers: {
          "User-Agent":
              "Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0",
          "Accept": "*/*",
          "Accept-Language": "en-US,en;q=0.5",
          "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
          "X-Requested-With": "XMLHttpRequest",
          "Sec-Fetch-Dest": "empty",
          "Sec-Fetch-Mode": "cors",
          "Sec-Fetch-Site": "same-origin",
          "Priority": "u=0",
          "Pragma": "no-cache",
          "Cache-Control": "no-cache",
          "Host": "start.schulportal.hessen.de",
          "Accept-Encoding": "gzip, deflate, br, zstd",
          "Origin": "https://start.schulportal.hessen.de",
          "Connection": "keep-alive",
          "Referer":
              "https://start.schulportal.hessen.de/meinunterricht.php?a=view&id=$courseId",
        },
      ),
    );

    return response.data == '1';
  }
}
