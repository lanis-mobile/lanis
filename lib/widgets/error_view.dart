import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/client_status_exceptions.dart';

class ErrorView extends StatelessWidget {
  final Exception error;
  final void Function()? retry;
  final bool showAppBar;

  const ErrorView(
      {super.key, required this.error, this.showAppBar = false, this.retry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAppBar) ...[
          AppBar(),
          Spacer(),
        ],
        Icon(
          error is! NoConnectionException
              ? Icons.warning_rounded
              : Icons.wifi_off_rounded,
          size: 60,
        ),
        const SizedBox(
          height: 16.0,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Text(
              error is! NoConnectionException
                  ? AppLocalizations.of(context).errorOccurred
                  : AppLocalizations.of(context).noInternetConnection2,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(
          height: 16.0,
        ),
        if (retry != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                  onPressed: retry,
                  child: Text(AppLocalizations.of(context).tryAgain)),
            ],
          ),
        if (error is! NoConnectionException) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: OutlinedButton(
                    onPressed: () {
                      launchUrl(Uri.parse(
                          "https://github.com/alessioC42/lanis-mobile/issues"));
                    },
                    child: const Text("GitHub")),
              ),
            ],
          )
        ],
        if (showAppBar) Spacer(),
      ],
    );
  }
}
