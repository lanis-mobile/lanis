import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:liblanis/liblanis.dart';

import '../models/account_types.dart';

class OfflineAvailableAppletsSection extends ConsumerStatefulWidget {
  const OfflineAvailableAppletsSection({super.key});

  @override
  ConsumerState<OfflineAvailableAppletsSection> createState() =>
      _OfflineAvailableAppletsSectionState();
}

class _OfflineAvailableAppletsSectionState
    extends ConsumerState<OfflineAvailableAppletsSection> {
  bool _loading = true;
  List<OfflineApplet> possibleOfflineApplets = [];

  Future<void> loadPossibleOfflineApplets() async {
    final db = ref.read(lanisDatabaseProvider);
    final accounts = await db.listAccounts();
    final offlineRows = db.listAppletOfflineData();
    final loaded = <OfflineApplet>[];

    for (final row in offlineRows) {
      final account = accounts
          .where((a) => a.localId == row.accountId)
          .firstOrNull;
      if (account == null) continue;
      loaded.add(
        OfflineApplet(
          localUserId: account.localId,
          userDisplayName: accounts.length > 1
              ? "${account.schoolName} (${account.username})"
              : account.schoolName,
          appletId: row.appletId,
          accountType: account.accountType,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      possibleOfflineApplets = loaded;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(loadPossibleOfflineApplets);
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
                  await ref
                      .read(activeAccountProvider.notifier)
                      .select(offlineApplet.localUserId);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          offlineApplet.definition.bodyBuilder!(
                            context,
                            offlineApplet.accountType ?? AccountType.student,
                            null,
                          ),
                    ),
                  );
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
