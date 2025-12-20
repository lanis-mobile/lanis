import 'package:flutter/material.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/core/database/account_database/account_db.dart';

import '../core/database/account_preferences_database/account_preferences_db.dart';
import '../core/sph/sph.dart';
import '../models/account_types.dart';

class OfflineAvailableAppletsSection extends StatefulWidget {
  const OfflineAvailableAppletsSection({super.key});

  @override
  State<OfflineAvailableAppletsSection> createState() =>
      _OfflineAvailableAppletsSectionState();
}

class _OfflineAvailableAppletsSectionState
    extends State<OfflineAvailableAppletsSection> {
  bool _loading = true;
  List<OfflineApplet> possibleOfflineApplets = [];

  Future<void> loadPossibleOfflineApplets() async {
    final accounts = await accountDatabase
        .select(accountDatabase.accountsTable)
        .get();
    for (final account in accounts) {
      final userDatabase = AccountPreferencesDatabase(localId: account.id);
      final applets = await userDatabase.select(userDatabase.appletData).get();
      for (final applet in applets) {
        if (applet.json != null) {
          possibleOfflineApplets.add(
            OfflineApplet(
              localUserId: account.id,
              userDisplayName: accounts.length > 1
                  ? "${account.schoolName} (${account.username})"
                  : account.schoolName,
              appletId: applet.appletId,
            ),
          );
        }
      }
      userDatabase.close();
    }

    setState(() {
      possibleOfflineApplets = possibleOfflineApplets;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadPossibleOfflineApplets();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: LinearProgressIndicator(),
      );
    }
    return SafeArea(
      child: Column(
        children: possibleOfflineApplets
            .map(
              (offlineApplet) => ListTile(
                title: Text(offlineApplet.definition.label(context)),
                subtitle: Text(offlineApplet.userDisplayName),
                leading: offlineApplet.definition.icon,
                onTap: () async {
                  ClearTextAccount acc = await accountDatabase
                      .getClearTextAccountFromId(offlineApplet.localUserId);
                  sph = SPH(account: acc);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            offlineApplet.definition.bodyBuilder!(
                              context,
                              acc.accountType ?? AccountType.student,
                              null,
                            ),
                      ),
                    );
                  }
                },
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class OfflineApplet {
  int? _definitionIndex;

  final int localUserId;
  final String userDisplayName;
  final String appletId;
  final AccountType? accountType;

  int get _defIndex =>
      _definitionIndex ??= AppDefinitions.getIndexByPhpIdentifier(appletId);

  AppletDefinition get definition => AppDefinitions.applets[_defIndex];

  OfflineApplet({
    required this.localUserId,
    required this.userDisplayName,
    required this.appletId,
    this.accountType,
  });
}
