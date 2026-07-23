import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/widgets/large_appbar.dart';

class ResetAccountPage extends ConsumerStatefulWidget {
  const ResetAccountPage({super.key});

  @override
  ConsumerState<ResetAccountPage> createState() => _ResetAccountPageState();
}

class _ResetAccountPageState extends ConsumerState<ResetAccountPage> {
  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) {
      return Scaffold(
        appBar: LargeAppBar(
          title: Text(AppLocalizations.of(context).resetAccount),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                ),
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
                        account.username,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
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
                        account.schoolName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.password,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondary.withRed(255),
                      ),
                      Text(
                        '••••••••••••••••••••',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondary.withRed(255),
                        ),
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
                        title: Text(
                          AppLocalizations.of(context).changePassword,
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: TextFormField(
                              controller: controller,
                              autofillHints: [AutofillHints.password],
                              autocorrect: false,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(
                                  context,
                                ).authPasswordHint,
                              ),
                              autovalidateMode: AutovalidateMode.always,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(
                                    context,
                                  ).authValidationError;
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
                                AppLocalizations.of(context).changePassword,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (newPassword == null) return;
                    final config = ref.read(lanisConfigProvider);
                    try {
                      await LanisSession.getLoginURL(
                        account.copyWith(password: newPassword),
                        config,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e is LanisException
                                ? e.cause
                                : AppLocalizations.of(context).unknownError,
                          ),
                        ),
                      );
                      return;
                    }
                    await ref
                        .read(accountsProvider.notifier)
                        .updatePassword(account.localId, newPassword);
                    final ok = await ref
                        .read(authControllerProvider.notifier)
                        .loginWithAccount(account.localId);
                    if (context.mounted && ok) context.go('/startup');
                  },
                  icon: Icon(Icons.password),
                  label: Text(AppLocalizations.of(context).changePassword),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(accountsProvider.notifier)
                        .remove(account.localId);
                    await ref.read(authControllerProvider.notifier).bootstrap();
                    if (context.mounted) context.go('/startup');
                  },
                  icon: Icon(Icons.no_accounts),
                  label: Text(AppLocalizations.of(context).removeAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
