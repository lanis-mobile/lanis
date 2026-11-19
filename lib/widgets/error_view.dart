import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/safe_launch.dart';

import 'package:liblanis/liblanis.dart';

import '../utils/mono_text_viewer.dart';

/// A missing offline snapshot is an expected empty state, not a diagnostic error.
class OfflineDataUnavailableView extends StatelessWidget {
  const OfflineDataUnavailableView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.cloud_off_outlined,
      size: 60,
      semanticLabel: AppLocalizations.of(context).offlineDataUnavailable,
    ),
  );
}

class AppletErrorView extends StatelessWidget {
  final Exception error;
  final void Function()? retry;
  final bool showAppBar;
  final StackTrace? stack;

  const AppletErrorView({
    super.key,
    required this.error,
    this.showAppBar = false,
    this.retry,
    this.stack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAppBar) ...[AppBar(), Spacer()],
        Icon(
          error is! NoConnectionException
              ? Icons.warning_rounded
              : Icons.wifi_off_rounded,
          size: 60,
        ),
        const SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Text(
            error is CacheUnavailableException
                ? AppLocalizations.of(context).offlineDataUnavailable
                : error is NoConnectionException
                ? AppLocalizations.of(context).noInternetConnection2
                : AppLocalizations.of(context).errorOccurred,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16.0),
        if (retry != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: retry,
                child: Text(AppLocalizations.of(context).tryAgain),
              ),
            ],
          ),
        if (error is! NoConnectionException &&
            error is! CacheUnavailableException) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  safeLaunchUrl(
                    Uri.parse("https://github.com/lanis-mobile/lanis/issues"),
                    context: context,
                  );
                },
                child: const Text("GitHub"),
              ),
            ],
          ),
        ],
        if (stack != null) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MonoTextViewer(
                        report: "$error\n\n$stack",
                        title: "Stack Trace",
                        fileNameStart: "stack_trace_applet",
                      ),
                    ),
                  );
                },
                child: const Text("Stack Trace"),
              ),
            ],
          ),
        ],
        if (showAppBar) Spacer(),
      ],
    );
  }
}

// test weather the exeptoin stack is present here...
