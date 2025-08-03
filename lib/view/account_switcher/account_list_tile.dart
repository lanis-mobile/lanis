import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import '../../core/database/account_database/account_db.dart';
import '../../core/sph/sph.dart';
import '../../utils/authentication_state.dart';
import '../../utils/random_color.dart';

class AccountListTile extends StatelessWidget {
  final int dbID;
  final String schoolName;
  final String userName;
  final DateTime lastLogin;
  final Function? onTap;

  const AccountListTile(
      {super.key,
      required this.schoolName,
      required this.userName,
      required this.lastLogin,
      required this.dbID,
      this.onTap});

  String get lastLoginInDays {
    final days = DateTime.now().difference(lastLogin).inDays;
    return days == 0 ? 'Today' : '$days days ago';
  }

  bool get isLoggedInAccount => sph?.account.localId == dbID;

  @override
  Widget build(BuildContext context) {
    ColorPair userColor = RandomColor.bySeed("$userName$schoolName$dbID");
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
            ),
            if (isLoggedInAccount)
              Text(
                'Active Account',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
              ),
            Spacer(),
            Text(
              lastLoginInDays,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(
              width: 16,
            ),
          ],
        ),
        ListTile(
          leading: Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: userColor.primary,
              border: Border.all(color: userColor.inversePrimary, width: 2),
            ),
            child: Center(
              child: Text(
                userName[0].toUpperCase(),
                style: TextStyle(
                  color: userColor.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          title: Text(userName.toLowerCase()),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Text(
                  schoolName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(lastLoginInDays),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              bool? result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(AppLocalizations.of(context).logout),
                  content:
                      Text(AppLocalizations.of(context).logoutConfirmation),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (result == true) {
                bool restart = isLoggedInAccount;
                if (restart) {
                  sph!.session.deAuthenticate();
                }
                await accountDatabase.deleteAccount(dbID);
                if (restart && context.mounted) {
                  authenticationState.reset(context);
                }
              }
            },
          ),
          onTap: () => onTap?.call(),
        ),
        Divider(),
      ],
    );
  }
}
