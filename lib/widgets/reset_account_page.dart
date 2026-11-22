import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/features/auth/account_recovery.dart';
import 'package:lanis/l10n/login_errors.dart';
import 'package:lanis/widgets/large_appbar.dart';

class ResetAccountPage extends ConsumerStatefulWidget {
  const ResetAccountPage({
    super.key,
    required this.account,
    this.removalOnly = false,
  });

  final ClearTextAccount account;
  final bool removalOnly;

  @override
  ConsumerState<ResetAccountPage> createState() => _ResetAccountPageState();
}

class _ResetAccountPageState extends ConsumerState<ResetAccountPage> {
  Future<void> _updatePassword(ClearTextAccount account) async {
    final newPassword = await _promptForPassword(account.username);
    if (!mounted || newPassword == null) return;
    try {
      await verifyAccountLogin(
        account.copyWith(password: newPassword),
        ref.read(lanisConfigProvider),
        ref.read(connectionCheckerProvider),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = e is LanisException
          ? localizedAccountLoginError(l10n, e) ?? e.cause
          : l10n.unknownError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    if (!mounted) return;

    await ref.read(accountsProvider.notifier).updatePassword(
      account.localId,
      newPassword,
    );
    if (!mounted) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .loginWithAccount(account.localId);
    if (mounted && ok) context.go('/startup');
  }

  Future<String?> _promptForPassword(String username) {
    final l10n = AppLocalizations.of(context);
    var password = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          if (password.isNotEmpty) Navigator.of(dialogContext).pop(password);
        }

        return AlertDialog(
          title: Text(l10n.changePassword),
          scrollable: true,
          content: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: username,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: l10n.accountUsername,
                    suffixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  autofocus: true,
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: l10n.authPasswordHint),
                  onChanged: (value) => password = value,
                  onFieldSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(onPressed: submit, child: Text(l10n.changePassword)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final l10n = AppLocalizations.of(context);

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
                  if (!widget.removalOnly) ...[
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.password,
                          color: Theme.of(context).colorScheme.onSecondary
                              .withRed(255),
                        ),
                        Text(
                          '••••••••••••••••••••',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary
                                .withRed(255),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: widget.removalOnly
                ? Text(l10n.deleteAccountFromDevice)
                : Text(l10n.wrongPassword),
            subtitle: widget.removalOnly ? null : Text(l10n.wrongPasswordHint),
          ),
          Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.removalOnly)
                  ElevatedButton.icon(
                    onPressed: () => _updatePassword(account),
                    icon: Icon(Icons.password),
                    label: Text(AppLocalizations.of(context).changePassword),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: Icon(Icons.no_accounts),
                  label: Text(
                    widget.removalOnly
                        ? l10n.deleteAccount
                        : l10n.removeAccount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
