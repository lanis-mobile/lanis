import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/core/database/account_database/account_db.dart';
import 'package:lanis/utils/large_appbar.dart';

import '../core/sph/sph.dart';
import '../utils/authentication_state.dart';

class ResetAccountPage extends StatefulWidget {
  const ResetAccountPage({super.key});

  @override
  State<ResetAccountPage> createState() => _ResetAccountPageState();
}

class _ResetAccountPageState extends State<ResetAccountPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LargeAppBar(
        title: Text(AppLocalizations.of(context).resetAccount),
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                    color: Theme.of(context).colorScheme.tertiaryContainer),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.login,
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                      Text(
                        sph!.account.username,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary),
                      ),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                      Text(
                        sph!.account.schoolName,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary),
                      ),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.password,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondary
                            .withRed(255),
                      ),
                      Text(
                        '••••••••••••••••••••',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondary
                                .withRed(255)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text(AppLocalizations.of(context).wrongPassword),
            subtitle: Text(AppLocalizations.of(context).wrongPasswordHint),
          ),
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    TextEditingController controller = TextEditingController();
                    final String? newPassword = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title:
                            Text(AppLocalizations.of(context).changePassword),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: TextFormField(
                              controller: controller,
                              autofillHints: [AutofillHints.password],
                              autocorrect: false,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)
                                    .authPasswordHint,
                              ),
                              autovalidateMode: AutovalidateMode.always,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(context)
                                      .authValidationError;
                                }
                                return null;
                              },
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: () {
                                if (controller.text.isEmpty) return;
                                Navigator.of(context).pop(controller.text);
                              },
                              child: Text(
                                  AppLocalizations.of(context).changePassword),
                            ),
                          )
                        ],
                      ),
                    );
                    if (newPassword == null) return;
                    await accountDatabase.updatePassword(
                        sph!.account.localId, newPassword);
                    if (context.mounted) {
                      authenticationState.reset(context);
                    }
                  },
                  icon: Icon(Icons.password),
                  label: Text(AppLocalizations.of(context).changePassword),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await accountDatabase.deleteAccount(sph!.account.localId);
                    if (context.mounted) {
                      authenticationState.reset(context);
                    }
                  },
                  icon: Icon(Icons.no_accounts),
                  label: Text(AppLocalizations.of(context).removeAccount),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
