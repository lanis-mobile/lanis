import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/l10n/login_errors.dart';
import 'package:lanis/utils/notification_navigation.dart';
import 'account_tile.dart';

class AccountSwitcher extends ConsumerStatefulWidget {
  const AccountSwitcher({super.key});

  @override
  ConsumerState<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends ConsumerState<AccountSwitcher> {
  bool _switching = false;

  Future<void> _switchAccount(int accountId) async {
    if (_switching) return;
    ref.read(notificationNavigationProvider).clearPending();
    if (ref.read(activeAccountProvider)?.localId == accountId &&
        ref.read(authControllerProvider).phase == AuthPhase.authenticated) {
      context.pop();
      return;
    }

    setState(() => _switching = true);
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccountResult(accountId);
      if (!mounted) return;
      if (result.succeeded) {
        context.go(firstSupportedHomePath(ref));
        return;
      }
      final l10n = AppLocalizations.of(context);
      final failure = result.failure;
      final message = localizedAccountLoginError(l10n, failure) ??
          (failure is UnknownException ? null : failure?.cause) ??
          l10n.unknownError;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.error),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).switchAccount)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (accounts) {
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AccountTile(
                account: account,
                lastLogin: account.lastLogin ?? DateTime.now(),
                onTap: _switching ? null : () => _switchAccount(account.localId),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _switching ? null : () => context.push('/login'),
        label: Text(AppLocalizations.of(context).addAccount),
        icon: Icon(Icons.person_add),
      ),
    );
  }
}
