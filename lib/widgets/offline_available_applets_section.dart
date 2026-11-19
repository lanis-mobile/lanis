import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/features/offline/cache_context.dart';
import 'package:lanis/features/offline/offline_applet_page.dart';
import 'package:liblanis/liblanis.dart';

class OfflineAvailableAppletsSection extends ConsumerStatefulWidget {
  const OfflineAvailableAppletsSection({super.key});
  @override
  ConsumerState<OfflineAvailableAppletsSection> createState() =>
      _OfflineAvailableAppletsSectionState();
}

class _OfflineAvailableAppletsSectionState
    extends ConsumerState<OfflineAvailableAppletsSection>
    with WidgetsBindingObserver {
  bool _loading = true;
  List<
    ({AccountSummary account, CachedAppletHome<dynamic> home, DateTime expiry})
  >
  _available = [];
  int _accountCount = 0;
  Timer? _expiry;
  Future<void> loadPossibleOfflineApplets() async {
    final db = ref.read(lanisDatabaseProvider);
    final cache = ref.read(cacheServiceProvider);
    await CachedAppletHomes.migrateLegacyTimetables(db);
    final accounts = await db.listAccounts();
    final loaded =
        <
          ({
            AccountSummary account,
            CachedAppletHome<dynamic> home,
            DateTime expiry,
          })
        >[];
    for (final account in accounts) {
      for (final home in CachedAppletHomes.all) {
        if (home.accountType != account.accountType) continue;
        final definition = AppDefinitions.getByPhpIdentifier(
          home.applet.appletPhpUrl,
        );
        if (!definition.allowOffline ||
            !definition.supportedAccountTypes.contains(account.accountType)) {
          continue;
        }
        final availability = await cache.inspectCacheFor(
          accountId: account.localId,
          request: home.request(),
        );
        if (availability.isAvailable) {
          loaded.add((
            account: account,
            home: home,
            expiry: availability.expiresAt!,
          ));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _available = loaded;
      _accountCount = accounts.length;
      _loading = false;
    });
    _expiry?.cancel();
    if (loaded.isNotEmpty) {
      final next = loaded
          .map((entry) => entry.expiry)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final delay = next.difference(DateTime.now());
      _expiry = Timer(
        delay.isNegative ? Duration.zero : delay,
        () => loadPossibleOfflineApplets(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(loadPossibleOfflineApplets);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(loadPossibleOfflineApplets());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    super.dispose();
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
        children: [
          for (final entry in _available)
            ListTile(
              title: Text(
                AppDefinitions.getByPhpIdentifier(
                  entry.home.applet.appletPhpUrl,
                ).label(context),
              ),
              subtitle: Text(
                _accountCount > 1
                    ? '${entry.account.schoolName} (${entry.account.username})'
                    : entry.account.schoolName,
              ),
              leading: AppDefinitions.getByPhpIdentifier(
                entry.home.applet.appletPhpUrl,
              ).icon,
              onTap: () async {
                final db = ref.read(lanisDatabaseProvider);
                final offline = OfflineCacheContext(
                  account: entry.account,
                  cache: ref.read(cacheServiceProvider),
                  settings: TypedSettings.account(db, entry.account.localId),
                  config: ref.read(lanisConfigProvider),
                );
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OfflineAppletPage(context: offline, home: entry.home),
                  ),
                );
                if (mounted) await loadPossibleOfflineApplets();
              },
            ),
        ],
      ),
    );
  }
}
