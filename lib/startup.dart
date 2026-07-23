import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/auth_controller.dart';
import 'package:lanis/utils/quick_actions.dart';
import 'package:lanis/widgets/offline_available_applets_section.dart';
import 'package:lanis/widgets/reset_account_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Splash / auth progress / recoverable auth errors.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();
    requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authControllerProvider);
      // In-app login failure may land here already in error (no phase transition).
      if (auth.phase == AuthPhase.error && auth.exception != null) {
        if (!mounted) return;
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          builder: (context) => errorDialog(context, auth.exception),
        );
        return;
      }
      // Skip if loginWithAccount already drives auth — must not selectPreferred.
      await ref.read(authControllerProvider.notifier).bootstrapIfNeeded();
      if (ref.read(authControllerProvider).phase == AuthPhase.authenticated) {
        QuickActionsStartUp();
      }
    });
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
            AppLocalizations.of(context).systemPermissionForNotificationsExplained,
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

  Widget errorDialog(BuildContext context, LanisException? exception) {
    final isDown = exception is LanisDownException;
    final isOffline = exception is NoConnectionException;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              isDown
                  ? AppLocalizations.of(context).lanisDown
                  : isOffline
                  ? AppLocalizations.of(context).noInternetConnection2
                  : AppLocalizations.of(context).error,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              exception?.cause ?? AppLocalizations.of(context).unknownError,
              textAlign: TextAlign.center,
            ),
            if (isOffline) ...[
              const SizedBox(height: 16),
              const OfflineAvailableAppletsSection(),
            ],
            if (exception is WrongCredentialsException)
              TextButton(
                onPressed: () {
                  context.go('/login');
                },
                child: Text(AppLocalizations.of(context).logInTitle),
              ),
            if (isDown)
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://start.schulportal.hessen.de/'),
                ),
                child: Text(AppLocalizations.of(context).openLanisInBrowser),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).retry();
              },
              child: Text(AppLocalizations.of(context).tryAgain),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResetAccountPage()),
                );
              },
              child: Text(AppLocalizations.of(context).resetAccount),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.phase == AuthPhase.error && auth.exception != null) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: errorDialog(context, auth.exception),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
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
      ),
    );
  }
}
