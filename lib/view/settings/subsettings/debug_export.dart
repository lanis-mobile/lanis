import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lanis/utils/file_operations.dart';

import '../../../core/sph/sph.dart';
import '../../../utils/logger.dart';

class DebugExport extends StatefulWidget {
  const DebugExport({super.key});

  @override
  State<DebugExport> createState() => _DebugExportState();
}

class _DebugExportState extends State<DebugExport> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController urlController = TextEditingController();
  final TextEditingController methodController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController headersController = TextEditingController();
  final TextEditingController queryParamsController = TextEditingController();
  bool authenticated = true;

  @override
  void initState() {
    super.initState();
    methodController.text = 'GET';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Export'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.warning,
              color: Colors.red,
            ),
            title: Text('UFFGEPASST!'),
            subtitle: Text(
                'Über diese Sektion kannst du Debug-Daten exportieren. Versende diese Daten nur an vertrauenswürdige Entwickler. Lösche die Daten, sobald du sie nicht mehr benötigst. Sie können sensible Informationen enthalten, die die Schule und dich betreffen.'),
          ),
          ListTile(
            leading: Icon(Icons.contact_mail),
            title: Text('Mit wem hast du Kontakt?'),
            subtitle: Text(
                'Wenn du Debug-Daten exportierst, stelle sicher, dass du sie ausschließlich an lanis-mobile@alessioc42.dev sendest. Diese E-Mail-Adresse wird von dem Hauptentwickler betreut. Sende die Daten auf keinen Fall an andere E-Mail-Adressen oder über andere Wege!'),
          ),
          Divider(),
          Form(
              key: formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  spacing: 8.0,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'HTTP Method',
                        border: OutlineInputBorder(),
                      ),
                      value: 'GET',
                      items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                          .map((method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
                              ))
                          .toList(),
                      onChanged: (value) {
                        methodController.text = value ?? 'GET';
                      },
                    ),
                    TextFormField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a URL';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: headersController,
                      decoration: InputDecoration(
                        labelText: 'Headers (JSON: { "key": "value" })',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    TextFormField(
                      controller: queryParamsController,
                      decoration: InputDecoration(
                        labelText: 'Query Params (JSON: { "key": "value" })',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    TextFormField(
                      controller: bodyController,
                      decoration: InputDecoration(
                        labelText: 'Body (for POST/PUT/PATCH)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    CheckboxListTile(
                      value: authenticated,
                      onChanged: (bool? value) {
                        setState(() {
                          authenticated = value ?? true;
                        });
                      },
                      title: Text("Authenticated Request"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final report = await createDebugExport(
                              context,
                              urlController.text,
                              methodController.text,
                              bodyController.text,
                              headersController.text,
                              queryParamsController.text,
                              authenticated);
                          // show full screen dialog with report as scrollable text
                          if (context.mounted) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => Scaffold(
                                      appBar: AppBar(
                                          title: Text('Debug Export Report')),
                                      body: SingleChildScrollView(
                                        padding: const EdgeInsets.only(
                                            left: 8.0,
                                            right: 8.0,
                                            top: 8.0,
                                            bottom: 100.0),
                                        child: SelectableText(report,
                                            style: TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 10)),
                                      ),
                                      floatingActionButton:
                                          FloatingActionButton.extended(
                                        label: Text('Export Report File'),
                                        icon: Icon(Icons.save_alt),
                                        onPressed: () {
                                          final fileName =
                                              'lanis_mobile_debug_export_${DateTime.now().toIso8601String()}.txt';
                                          final file = File(
                                              '${Directory.systemTemp.path}/$fileName');
                                          file.writeAsString(report).then((_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Report saved to ${file.path}')),
                                              );
                                            }
                                          }).catchError((e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Failed to save report: $e')),
                                              );
                                            }
                                          });
                                          showFileModal(
                                              context,
                                              FileInfo.local(
                                                  filePath: file.path,
                                                  name: fileName,
                                                  size: ""));
                                        },
                                      ),
                                    )));
                          }
                        }
                      },
                      child: Text('Export Debug Data'),
                    ),
                  ],
                ),
              ))
        ],
      ),
    );
  }

  Future<String> createDebugExport(
      BuildContext context,
      String url,
      String httpMethod,
      String body,
      String headersJson,
      String queryJson,
      bool authenticated) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    MemoryLogger report = MemoryLogger();
    report.log('START: Debug Export');
    report.log('SCHOOL: ${sph!.account.schoolID} (${sph!.account.schoolName})');
    report.log(
        'PLATFORM: ${Platform.operatingSystem} ${Platform.version} ${Platform.operatingSystemVersion}');
    report.log(
        'APP VERSION: ${packageInfo.appName} ${packageInfo.buildNumber} ${packageInfo.version}');
    report.log('INSTALL STORE: ${packageInfo.installerStore}');
    report.write('------------- BEGIN REQUEST DESCRIPTION -------------');
    report.log('URL: $url');
    report.log('Method: $httpMethod');
    report.log('Body:\n$body');
    report.log('Headers:\n$headersJson');
    report.log('Query Params:\n$queryJson');
    report.log('Authenticated: $authenticated');
    report.write('------------- END REQUEST DESCRIPTION -------------');
    final dio = authenticated ? sph!.session.dio : Dio();

    try {
      final response = await dio.request(
        url,
        options: Options(
          method: httpMethod,
          headers: headersJson.isNotEmpty
              ? Map<String, dynamic>.from(jsonDecode(headersJson))
              : {},
          contentType: 'application/json',
          validateStatus: (_) => true, // Allow all status codes
        ),
        data: body.isNotEmpty ? jsonDecode(body) : null,
        queryParameters: queryJson.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(queryJson))
            : {},
      );
      report.write("------------- BEGIN RESPONSE -------------");
      report.log(
          'Status Code: ${response.statusCode} (${response.statusMessage})');
      report.write('-------- BEGIN HEADER --------');
      for (var key in response.headers.map.keys) {
        report.write("$key: ${response.headers.value(key)}");
      }
      report.write('-------- END HEADER --------');
      report.write("-------- BEGIN BODY --------");
      if (response.data is String) {
        report.write(response.data);
      } else if (response.data is Map || response.data is List) {
        report.write(jsonEncode(response.data));
      } else {
        report.write(response.data.toString());
      }
      report.write("-------- END BODY --------");
      report.write("------------- END RESPONSE -------------");
    } catch (e, stackTrace) {
      report.log(" ----- AN ERROR OCCURRED WHILE CREATING THE REPORT -----");
      report.write(e.toString());
      report.write(stackTrace.toString());
    }
    return report.logs;
  }
}
