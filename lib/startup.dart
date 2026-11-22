import 'package:app_settings/app_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/features/auth/account_recovery.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/l10n/login_errors.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/widgets/offline_available_applets_section.dart';
import 'package:lanis/widgets/reset_account_page.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/utils/server_status.dart';

/// Splash / auth progress / recoverable auth errors.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

enum _RecoveryAction { retry, switchAccount, deleteAccount }

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _errorSheetOpen = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authControllerProvider);
      // In-app login failure may land here already in error (no phase transition).
      if (auth.phase == AuthPhase.error && auth.exception != null) {
        await _showErrorSheet(auth.exception!);
        return;
      }
      final shared = ref.read(sharedOverAccountSettingsProvider);
      final accounts = await ref.read(accountsProvider.future);
      if (!mounted) return;
      // First-time installs accept privacy on the login form instead.
      if (accounts.isNotEmpty && !isPrivacyPolicyAccepted(shared)) {
        context.go('/privacy-policy');
        return;
      }
      // Skip if loginWithAccount already drives auth — must not selectPreferred.
      await ref.read(authControllerProvider.notifier).bootstrapIfNeeded();
    });
  }

  Future<void> _showErrorSheet(LanisException exception) async {
    if (_errorSheetOpen || !mounted) return;
    final account = ref.read(activeAccountProvider);
    _errorSheetOpen = true;
    try {
      final action = await showModalBottomSheet<_RecoveryAction>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        builder: (sheetContext) {
          void finish(_RecoveryAction action) {
            if (ModalRoute.of(sheetContext)?.isCurrent == true) {
              Navigator.pop(sheetContext, action);
            }
          }

          return StartupAuthErrorContent(
            exception: exception,
            account: account,
            onOpenPortal: account == null
                ? null
                : () => openPortalPasswordChange(
                    sheetContext,
                    account,
                    ref.read(lanisConfigProvider),
                  ),
            onSwitchAccount: () => finish(_RecoveryAction.switchAccount),
            onDeleteAccount: () => finish(_RecoveryAction.deleteAccount),
            onRetry: () => finish(_RecoveryAction.retry),
          );
        },
      );
      if (!mounted || action == null) return;
      final auth = ref.read(authControllerProvider.notifier);
      switch (action) {
        case _RecoveryAction.retry:
          await auth.retry();
        case _RecoveryAction.switchAccount:
          await context.push('/accounts');
          if (mounted &&
              ref.read(authControllerProvider).phase ==
                  AuthPhase.authenticated) {
            context.go(firstSupportedHomePath(ref));
          }
        case _RecoveryAction.deleteAccount:
          if (account != null) {
            await auth.removeAccountAndContinue(account.localId);
          }
      }
    } finally {
      _errorSheetOpen = false;
    }
    if (mounted) _scheduleErrorSheet();
  }

  void _scheduleErrorSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      if (auth.phase == AuthPhase.error && auth.exception != null) {
        _showErrorSheet(auth.exception!);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isGranted) return;
    if (status.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.notifications_outlined),
          title: Text(AppLocalizations.of(context).notifications),
          content: Text(
            AppLocalizations.of(
              context,
            ).systemPermissionForNotificationsExplained,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                AppSettings.openAppSettings();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context).settings),
            ),
          ],
        ),
      );
    }
  }

  Widget _splashBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/startup.svg', height: 96, width: 96),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Text(
                'v${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.phase == AuthPhase.error && next.exception != null) {
        if (previous?.phase == AuthPhase.error &&
            previous?.exception == next.exception) {
          return;
        }
        _scheduleErrorSheet();
      }
    });

    return Scaffold(body: _splashBody());
  }
}

/// Main-parity auth error chrome for the startup bottom sheet.
class StartupAuthErrorContent extends StatelessWidget {
  final LanisException exception;
  final ClearTextAccount? account;
  final VoidCallback onRetry;
  final VoidCallback? onOpenPortal;
  final VoidCallback? onSwitchAccount;
  final VoidCallback? onDeleteAccount;

  const StartupAuthErrorContent({
    super.key,
    required this.exception,
    required this.onRetry,
    this.account,
    this.onOpenPortal,
    this.onSwitchAccount,
    this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDown = exception is LanisDownException;
    final isOffline = exception is NoConnectionException;
    final accountError = localizedAccountLoginError(l10n, exception);
    final passwordChange = exception is PasswordChangeRequiredException;
    final removalOnly =
        passwordChange ||
        exception is ParentAccountWithoutLearnersException ||
        exception is AccountDisabledException;

    final title = isDown
        ? l10n.lanisDownError
        : isOffline
        ? l10n.noInternetConnection2
        : accountError == null
        ? l10n.startupError
        : l10n.error;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.wifi_find_outlined),
                    onPressed: () => safeLaunchUrl(
                      Uri.parse(serverStatusUrl),
                      context: context,
                    ),
                    tooltip: l10n.checkStatus,
                  ),
                  Icon(isOffline ? Icons.wifi_off : Icons.error, size: 48),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRetry,
                    tooltip: l10n.tryAgain,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: Text(title)),
              if (!isOffline && !isDown)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: accountError != null
                      ? Text(accountError, textAlign: TextAlign.center)
                      : Text.rich(
                          TextSpan(
                            text: l10n.startupErrorMessage,
                            children: [
                              TextSpan(
                                text:
                                    '\n\n${exception.runtimeType}: ${exception.cause}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                ),
              if (passwordChange && onOpenPortal != null)
                FilledButton(
                  onPressed: onOpenPortal,
                  child: Text(l10n.openSchulportalHessen),
                ),
              if (account != null &&
                  (removalOnly || exception is WrongCredentialsException))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ElevatedButton.icon(
                    icon: Icon(removalOnly ? Icons.no_accounts : Icons.lock_reset),
                    label: Text(removalOnly ? l10n.deleteAccount : l10n.resetAccount),
                    onPressed: () async {
                      final delete = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => ResetAccountPage(
                            account: account!,
                            removalOnly: removalOnly,
                          ),
                        ),
                      );
                      if (context.mounted && delete == true) {
                        onDeleteAccount?.call();
                      }
                    },
                  ),
                ),
              if (removalOnly && onSwitchAccount != null)
                TextButton(
                  onPressed: onSwitchAccount,
                  child: Text(l10n.switchAccount),
                ),
              if (isDown)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    l10n.lanisDownErrorMessage,
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              const OfflineAvailableAppletsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
