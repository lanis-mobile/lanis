import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/models/account_types.dart';
import '../../core/database/account_database/account_db.dart';
import '../../core/sph/sph.dart';
import '../../utils/authentication_state.dart';
import '../../utils/random_color.dart';

class AccountTile extends StatelessWidget {
  final DateTime lastLogin;
  final Function? onTap;
  final AccountsTableData account;

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

  bool get isLoggedInAccount => sph?.account.localId == account.id;

  String accountTypeLabel(BuildContext context) {
    AccountType type = AccountTypeExtension.fromString(
      account.accountType!.split('.').last,
    );
    return type.readableName(context);
  }

  Widget avatar() {
    ColorPair userColor = RandomColor.bySeed(
      "${account.username}${account.schoolName}${account.id}",
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

  Widget logoutButton(BuildContext context) {
    return IconButton(
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
        if (result == true) {
          bool restart = isLoggedInAccount;
          if (restart) {
            sph!.session.deAuthenticate();
          }
          await accountDatabase.deleteAccount(account.id);
          if (restart && context.mounted) {
            authenticationState.reset(context);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isLoggedInAccount
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ListTile(
        onTap: onTap == null
            ? null
            : () {
                if (onTap != null) {
                  onTap!();
                }
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
        trailing: logoutButton(context),
      ),
    );
  }
}
