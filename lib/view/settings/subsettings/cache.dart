import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../core/sph/sph.dart';
import '../../../utils/callout.dart';

class CacheSettings extends SettingsColours {
  final bool showBackButton;
  const CacheSettings({super.key, this.showBackButton = true});

  static Future<Map<String, int>> dirStat(String dirPath) async {
    int fileNum = 0;
    int totalSize = 0;
    var dir = Directory(dirPath);

    if (await dir.exists()) {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          fileNum++;
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    }
    return {'fileNum': fileNum, 'size': totalSize};
  }

  @override
  State<CacheSettings> createState() => _CacheSettingsState();
}

class _CacheSettingsState extends SettingsColoursState<CacheSettings> {
  Map<String, int> cacheStats = {'fileNum': 0, 'size': 0};

  Future<void> clearCache() async {
    final dir = await sph!.storage.getDocumentCacheDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    final stats = await CacheSettings.dirStat(dir.path);
    setState(() {
      cacheStats = stats;
    });
  }

  @override
  void initState() {
    super.initState();

    sph!.storage.getDocumentCacheDirectory().then((dir) async {
      final stats = await CacheSettings.dirStat(dir.path);
      setState(() {
        cacheStats = stats;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).clearCache),
      showBackButton: widget.showBackButton,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        Text(
          AppLocalizations.of(context).settingsInfoClearCache,
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        SizedBox(
          height: 24.0,
        ),
        Callout(
          leading: Icon(Icons.delete_forever_rounded),
          title:
              Text(AppLocalizations.of(context).questionPermanentlyEmptyCache),
          buttonText: Text(
            cacheStats['fileNum'] != 0
                ? AppLocalizations.of(context).clearCache
                : AppLocalizations.of(context).cacheEmpty,
          ),
          onPressed: cacheStats['fileNum'] != 0
              ? () {
                  clearCache();
                }
              : null,
        ),
        SizedBox(
          height: 24.0,
        ),
        Text(
          AppLocalizations.of(context).spaceUsed,
          style: Theme.of(context)
              .textTheme
              .labelLarge!
              .copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        SizedBox(
          height: 16.0,
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${cacheStats['fileNum'].toString()} ${cacheStats['fileNum'] == 1 ? AppLocalizations.of(context).file : AppLocalizations.of(context).files}",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            Text(
              "${cacheStats['size']! ~/ 1024} KB",
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        SizedBox(
          height: 28.0,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20.0,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          ],
        ),
        SizedBox(
          height: 8.0,
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: AppLocalizations.of(context)
                    .otherStorageSettingsAvailablePart1,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              TextSpan(
                text: AppLocalizations.of(context).systemSettings,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    AppSettings.openAppSettings();
                  },
              ),
              TextSpan(
                text: AppLocalizations.of(context)
                    .otherStorageSettingsAvailablePart2,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            ],
          ),
        )
      ],
    );
  }
}
