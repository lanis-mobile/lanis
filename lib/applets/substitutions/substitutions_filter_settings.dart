import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';

import 'chips_input.dart';

class SubstitutionsFilterSettings extends ConsumerStatefulWidget {
  const SubstitutionsFilterSettings({super.key});

  @override
  ConsumerState<SubstitutionsFilterSettings> createState() =>
      _SubstitutionsFilterSettingsState();
}

class _SubstitutionsFilterSettingsState
    extends ConsumerState<SubstitutionsFilterSettings> {
  bool loadingFilter = false;
  @override
  Widget build(BuildContext context) {
    final parser = ref.watch(substitutionsParserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).substitutionsFilter),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
        children: [
          ElevatedButton(
            onPressed: () {
              parser.localFilter = {};
              parser.saveFilterToStorage();
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
            objKey: "Vertreter",
            title: "Vertreter",
          ),
          const SubstitutionFilterEditor(
            objKey: "Lehrerkuerzel",
            title: "Lehrerkürzel",
          ),
          const SubstitutionFilterEditor(
            objKey: "Vertreterkuerzel",
            title: "Vertreterkürzel",
          ),
          const SubstitutionFilterEditor(objKey: "Hinweis", title: "Hinweis"),
          const SubstitutionFilterEditor(
            objKey: "Fach_alt",
            title: "Fach (Alt)",
          ),
          const SubstitutionFilterEditor(
            objKey: "Raum_alt",
            title: "Raum (Alt)",
          ),
          SafeArea(
            child: ListTile(
              leading: const Icon(Icons.help),
              title: Text(AppLocalizations.of(context).howItWorks),
              subtitle: Text(AppLocalizations.of(context).howItWorksText),
            ),
          ),
        ],
      ),
    );
  }
}

class SubstitutionFilterEditor extends ConsumerStatefulWidget {
  final String objKey;
  final String title;

  const SubstitutionFilterEditor({
    super.key,
    required this.objKey,
    required this.title,
  });

  @override
  ConsumerState<SubstitutionFilterEditor> createState() =>
      _SubstitutionFilterEditorState();
}

class _SubstitutionFilterEditorState
    extends ConsumerState<SubstitutionFilterEditor> {
  bool strict = false;
  late List<String> filterTags;

  @override
  void initState() {
    super.initState();
    // localFilter is populated when the parser provider is first created;
    // read after first frame so the provider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final parser = ref.read(substitutionsParserProvider);
      setState(() {
        strict = parser.localFilter[widget.objKey]?["strict"] ?? false;
      });
    });
  }

  void overrideFilter(List<String> data) {
    final parser = ref.read(substitutionsParserProvider);
    parser.localFilter[widget.objKey] = {"strict": strict};
    parser.localFilter[widget.objKey]?["filter"] = data;
    parser.saveFilterToStorage();
  }

  @override
  Widget build(BuildContext context) {
    final parser = ref.watch(substitutionsParserProvider);
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
                    parser.localFilter[widget.objKey]?["strict"] = strict;
                    parser.saveFilterToStorage();
                  });
                },
              ),
            ],
          ),
          StringListEditor(
            initialValues:
                parser.localFilter[widget.objKey]?["filter"] ?? [],
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
