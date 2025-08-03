import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../core/sph/sph.dart';
import 'chips_input.dart';

class SubstitutionsFilterSettings extends StatefulWidget {
  const SubstitutionsFilterSettings({super.key});

  @override
  State<StatefulWidget> createState() => _SubstitutionsFilterSettingsState();
}

class _SubstitutionsFilterSettingsState
    extends State<SubstitutionsFilterSettings> {
  bool loadingFilter = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).substitutionsFilter),
        ),
        body: ListView(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
          children: [
            ElevatedButton(
              onPressed: () {
                sph!.parser.substitutionsParser.localFilter = {};
                sph!.parser.substitutionsParser.saveFilterToStorage();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context).reset),
            ),
            const SubstitutionFilterEditor(objKey: "Klasse", title: 'Klasse'),
            const SubstitutionFilterEditor(objKey: "Fach", title: 'Fach'),
            const SubstitutionFilterEditor(objKey: "Lehrer", title: 'Lehrer'),
            const SubstitutionFilterEditor(objKey: "Raum", title: 'Raum'),
            const SubstitutionFilterEditor(objKey: "Art", title: 'Art'),
            const SubstitutionFilterEditor(
                objKey: "Vertreter", title: "Vertreter"),
            const SubstitutionFilterEditor(
                objKey: "Lehrerkuerzel", title: "Lehrerkürzel"),
            const SubstitutionFilterEditor(
                objKey: "Vertreterkuerzel", title: "Vertreterkürzel"),
            const SubstitutionFilterEditor(objKey: "Hinweis", title: "Hinweis"),
            const SubstitutionFilterEditor(
                objKey: "Fach_alt", title: "Fach (Alt)"),
            const SubstitutionFilterEditor(
                objKey: "Raum_alt", title: "Raum (Alt)"),
            SafeArea(
              child: ListTile(
                  leading: const Icon(Icons.help),
                  title: Text(AppLocalizations.of(context).howItWorks),
                  subtitle: Text(AppLocalizations.of(context).howItWorksText)),
            )
          ],
        ));
  }
}

class SubstitutionFilterEditor extends StatefulWidget {
  final String objKey;
  final String title;

  const SubstitutionFilterEditor(
      {super.key, required this.objKey, required this.title});

  @override
  State<SubstitutionFilterEditor> createState() =>
      _SubstitutionFilterEditorState();
}

class _SubstitutionFilterEditorState extends State<SubstitutionFilterEditor> {
  bool strict = false;
  late List<String> filterTags;

  @override
  void initState() {
    super.initState();
    strict = sph!.parser.substitutionsParser.localFilter[widget.objKey]
            ?["strict"] ??
        false;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void overrideFilter(List<String> data) {
    sph!.parser.substitutionsParser.localFilter[widget.objKey] = {
      "strict": strict
    };
    sph!.parser.substitutionsParser.localFilter[widget.objKey]?["filter"] =
        data;
    sph!.parser.substitutionsParser.saveFilterToStorage();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(widget.title, style: const TextStyle(fontSize: 18)),
              ),
              ActionChip(
                label: strict ? const Text("All") : const Text("One"),
                padding: const EdgeInsets.only(top: 0, bottom: 0),
                onPressed: () {
                  setState(() {
                    strict = !strict;
                    sph!.parser.substitutionsParser.localFilter[widget.objKey]
                        ?["strict"] = strict;
                    sph!.parser.substitutionsParser.saveFilterToStorage();
                  });
                },
              )
            ],
          ),
          StringListEditor(
            initialValues: sph!.parser.substitutionsParser
                    .localFilter[widget.objKey]?["filter"] ??
                [],
            onChanged: (data) {
              filterTags = data;
              overrideFilter(data);
            },
          ),
        ],
      ),
    );
  }
}
