import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/random_color.dart';

class AccountTile extends ConsumerWidget {
  final DateTime lastLogin;
  final Function? onTap;
  final AccountSummary account;

  const AccountTile({
    super.key,
    required this.lastLogin,
    this.onTap,
    required this.account,
  });

  String lastLoginInDays(BuildContext context) {
    final days = DateTime.now().difference(lastLogin).inDays;
    return AppLocalizations.of(context).lastSeen(days);
  }

  String accountTypeLabel(BuildContext context) {
    final type = account.accountType ?? AccountType.student;
    return type.readableName(context);
  }

  Widget avatar() {
    ColorPair userColor = RandomColor.bySeed(
      "${account.username}${account.schoolName}${account.localId}",
    );
    return Container(
      height: 45,
      width: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: userColor.primary,
        border: Border.all(color: userColor.inversePrimary, width: 2),
      ),
      child: Center(
        child: Text(
          account.username[0].toUpperCase(),
          style: TextStyle(
            color: userColor.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAccountProvider);
    final isLoggedInAccount = active?.localId == account.localId;

    return Card(
      color: isLoggedInAccount
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ListTile(
        onTap: onTap == null
            ? null
            : () {
                onTap!();
              },
        leading: avatar(),
        title: Text("${account.username} (${accountTypeLabel(context)})"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.schoolName),
            Text(lastLoginInDays(context), style: TextStyle(fontSize: 12)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.logout),
          onPressed: () async {
            bool? result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context).logout),
                content: Text(AppLocalizations.of(context).logoutConfirmation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(AppLocalizations.of(context).cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(AppLocalizations.of(context).logout),
                  ),
                ],
              ),
            );
            if (result != true) return;
            final restart = isLoggedInAccount;
            if (restart) {
              await ref
                  .read(authControllerProvider.notifier)
                  .removeAccountAndContinue(account.localId);
              if (!context.mounted) return;
              final phase = ref.read(authControllerProvider).phase;
              context.go(
                phase == AuthPhase.authenticated
                    ? firstSupportedHomePath(ref)
                    : '/welcome',
              );
            } else {
              await ref.read(accountsProvider.notifier).remove(account.localId);
            }
          },
        ),
      ),
    );
  }
}
