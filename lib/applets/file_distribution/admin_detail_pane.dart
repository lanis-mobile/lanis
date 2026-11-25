import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:lanis/utils/url_modal.dart';
import 'package:lanis/widgets/file_chip.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

enum AdminDistributionStatus { active, scheduled, expired }

AdminDistributionStatus adminStatusOf(AdminFileDistributionSummary item) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (item.validFrom != null && item.validFrom!.isAfter(today)) {
    return AdminDistributionStatus.scheduled;
  }
  if (item.validUntil != null && item.validUntil!.isBefore(today)) {
    return AdminDistributionStatus.expired;
  }
  return AdminDistributionStatus.active;
}

class AdminDetailPane extends StatefulWidget {
  final AdminFileDistributionSummary summary;
  final FileDistributionParser parser;
  final int refreshVersion;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const AdminDetailPane({
    super.key,
    required this.summary,
    required this.parser,
    this.refreshVersion = 0,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  State<AdminDetailPane> createState() => _AdminDetailPaneState();
}

class _AdminDetailPaneState extends State<AdminDetailPane> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  static final RegExp _placeholderRe = RegExp(r'%[A-Za-zÄÖÜäöüß0-9_]+%');

  AdminFileDistributionDetail? _detail;
  FileDistributionStats? _stats;
  bool _loadingDetail = false;
  bool _loadingStats = false;
  String? _detailError;
  String? _statsError;
  bool _showStats = false;
  bool _uploading = false;
  int _detailGen = 0;
  int _statsGen = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void didUpdateWidget(covariant AdminDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.summary.id != widget.summary.id;
    final refreshed = oldWidget.refreshVersion != widget.refreshVersion;
    if (idChanged || refreshed) {
      _detailGen++;
      _statsGen++;
      _detail = idChanged ? null : _detail;
      _stats = null;
      _detailError = null;
      _statsError = null;
      _loadingStats = false;
      if (idChanged) _showStats = false;
      _loadDetail();
      if (!idChanged && _showStats) {
        _fetchStats();
      }
    }
  }

  Future<void> _loadDetail() async {
    final requestedId = widget.summary.id;
    final gen = ++_detailGen;
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final detail = await widget.parser.getAdminDistributionDetail(
        requestedId,
      );
      if (!mounted || widget.summary.id != requestedId || _detailGen != gen) {
        return;
      }
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted || widget.summary.id != requestedId || _detailGen != gen) {
        return;
      }
      setState(() {
        _detailError = e.toString();
        _loadingDetail = false;
      });
    }
  }

  Future<void> _toggleStats() async {
    if (_showStats) {
      setState(() => _showStats = false);
      return;
    }
    setState(() => _showStats = true);
    if (_stats != null || _loadingStats) return;
    await _fetchStats();
  }

  Future<void> _fetchStats() async {
    final requestedId = widget.summary.id;
    final gen = ++_statsGen;
    setState(() {
      _loadingStats = true;
      _statsError = null;
    });
    try {
      final stats = await widget.parser.getStatistics(requestedId);
      if (!mounted || widget.summary.id != requestedId || _statsGen != gen) {
        return;
      }
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    } catch (e) {
      if (!mounted || widget.summary.id != requestedId || _statsGen != gen) {
        return;
      }
      setState(() {
        _statsError = e.toString();
        _loadingStats = false;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_uploading) return;
    final targetId = widget.summary.id;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    var uploadedAny = false;
    final failedNames = <String>[];
    try {
      for (final file in files) {
        final path = file.path;
        if (path == null) continue;
        final bytes = await File(path).readAsBytes();
        final ok = await widget.parser.uploadFile(
          targetId,
          fileName: file.name,
          bytes: bytes,
        );
        if (ok) {
          uploadedAny = true;
        } else {
          failedNames.add(file.name);
        }
      }
      if (!mounted) return;
      if (failedNames.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('${l10n.error}: ${failedNames.join(', ')}')),
        );
      } else if (uploadedAny) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.fileDistributionAdminUploadSuccess)),
        );
      }
      if (uploadedAny) {
        widget.onRefresh();
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _formatDateRange() {
    final from = widget.summary.validFrom;
    final until = widget.summary.validUntil;
    if (from != null && until != null) {
      return '${_dateFormat.format(from)} – ${_dateFormat.format(until)}';
    }
    if (until != null) return _dateFormat.format(until);
    if (from != null) return _dateFormat.format(from);
    return null;
  }

  String _modeLabel(AppLocalizations l10n, DistributionMode mode) =>
      switch (mode) {
        DistributionMode.sharedFiles => l10n.fileDistributionAdminModeShared,
        DistributionMode.randomSingle => l10n.fileDistributionAdminModeRandom,
        DistributionMode.textOnly => l10n.fileDistributionAdminModeTextOnly,
        DistributionMode.placeholder =>
          l10n.fileDistributionAdminModePlaceholder,
      };

  Widget _buildStatusBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final status = adminStatusOf(widget.summary);
    final (label, bg, fg) = switch (status) {
      AdminDistributionStatus.active => (
        l10n.fileDistributionAdminFilterActive,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      AdminDistributionStatus.scheduled => (
        l10n.fileDistributionAdminFilterScheduled,
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      AdminDistributionStatus.expired => (
        l10n.fileDistributionAdminFilterExpired,
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  TextSpan _buildHighlightedNoticeSpan(BuildContext context, String text) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final colorScheme = Theme.of(context).colorScheme;
    final highlightStyle = baseStyle?.copyWith(
      color: colorScheme.onPrimaryContainer,
      backgroundColor: colorScheme.primaryContainer,
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _placeholderRe.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: highlightStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final summary = widget.summary;
    final detail = _detail;
    final dateRange = _formatDateRange();
    final progress = summary.totalRecipients > 0
        ? (summary.distributedCount / summary.totalRecipients).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildStatusBadge(context),
                        const SizedBox(width: 8),
                        Text(
                          _modeLabel(l10n, summary.mode),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.fileDistributionAdminEditTitle,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    tooltip: l10n.delete,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (dateRange != null)
                _MetaItem(icon: Icons.calendar_today_outlined, text: dateRange),
              if (summary.audienceLabel.isNotEmpty)
                _MetaItem(
                  icon: Icons.groups_outlined,
                  text: summary.audienceLabel,
                ),
              if (summary.creatorName != null &&
                  summary.creatorName!.isNotEmpty)
                _MetaItem(
                  icon: Icons.person_outline,
                  text: summary.creatorName!,
                ),
            ],
          ),
          if (_loadingDetail) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ] else if (_detailError != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _detailError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: _loadDetail,
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ],
          if (detail != null && detail.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText.rich(
                    _buildHighlightedNoticeSpan(context, detail.description),
                  ),
                ),
              ),
            ),
          ],
          if (summary.files.isNotEmpty || summary.canUpload) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final file in summary.files)
                  FileChip(
                    file: DownloadableFile(
                      name: file.name,
                      url: file.downloadUrl,
                    ),
                    fileExtension: file.fileExtension,
                  ),
                if (summary.canUpload)
                  ActionChip(
                    avatar: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined, size: 18),
                    label: Text(l10n.fileDistributionAdminUploadFile),
                    onPressed: _uploading ? null : _uploadFile,
                  ),
              ],
            ),
          ],
          if (detail != null && detail.infoLink != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => openUrlModal(context, detail.infoLink!.url),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(detail.infoLink!.title),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.fileDistributionAdminReadProgress(
                            summary.distributedCount,
                            summary.totalRecipients,
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _toggleStats,
                        icon: Icon(
                          _showStats
                              ? Icons.expand_less
                              : Icons.bar_chart_outlined,
                          size: 18,
                        ),
                        label: Text(l10n.fileDistributionAdminStatistics),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                    ),
                  ),
                  if (_showStats) ...[
                    const SizedBox(height: 12),
                    if (_loadingStats)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_statsError != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _statsError!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.error),
                            ),
                          ),
                          TextButton(
                            onPressed: _fetchStats,
                            child: Text(l10n.tryAgain),
                          ),
                        ],
                      )
                    else if (_stats != null && _stats!.groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '–',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    else if (_stats != null && _stats!.groups.isNotEmpty)
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                        },
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  l10n.fileDistributionAdminGroup,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  l10n.fileDistributionAdminRetrieved,
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  l10n.fileDistributionAdminPending,
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          for (final g in _stats!.groups)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    g.group,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${g.retrieved}',
                                    textAlign: TextAlign.end,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${g.pending}',
                                    textAlign: TextAlign.end,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
