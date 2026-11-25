import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

class AdminComposerPane extends StatefulWidget {
  final FileDistributionParser parser;
  final AdminFileDistributionDetail? initialDetail;
  final bool embeddedInSplitView;
  final VoidCallback onCancel;
  final ValueChanged<int> onSaved;

  const AdminComposerPane({
    super.key,
    required this.parser,
    this.initialDetail,
    this.embeddedInSplitView = false,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<AdminComposerPane> createState() => _AdminComposerPaneState();
}

class _AdminComposerPaneState extends State<AdminComposerPane> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noticeController;
  late final TextEditingController _linkUrlController;
  late final TextEditingController _linkTitleController;

  late DistributionAudience _audience;
  late DistributionMode _mode;
  late DateTime _validFrom;
  late DateTime _validUntil;
  final List<PlatformFile> _pendingFiles = [];
  bool _saving = false;

  bool get _isEditing => widget.initialDetail != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDetail;
    final now = DateTime.now();
    _titleController = TextEditingController(text: d?.title ?? '');
    _noticeController = TextEditingController(text: d?.description ?? '');
    _linkUrlController = TextEditingController(
      text: d?.infoLink?.url.toString() ?? '',
    );
    _linkTitleController = TextEditingController(
      text: d?.infoLink?.title ?? '',
    );
    _audience = d?.audience ?? DistributionAudience.students;
    _mode = d?.mode ?? DistributionMode.sharedFiles;
    _validFrom = d?.validFrom ?? DateTime(now.year, now.month, now.day);
    _validUntil =
        d?.validUntil ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noticeController.dispose();
    _linkUrlController.dispose();
    _linkTitleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _validFrom : _validUntil;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _validFrom = picked;
        if (_validUntil.isBefore(_validFrom)) {
          _validUntil = _validFrom;
        }
      } else {
        _validUntil = picked;
        if (_validFrom.isAfter(_validUntil)) {
          _validFrom = _validUntil;
        }
      }
    });
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    setState(() {
      _pendingFiles.addAll(files.where((f) => f.path != null));
    });
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final rawUrl = _linkUrlController.text.trim();
      final linkUrl = rawUrl.isNotEmpty ? Uri.tryParse(rawUrl) : null;
      final linkTitle = _linkTitleController.text.trim();

      final draft = FileDistributionDraft(
        id: widget.initialDetail?.id,
        title: _titleController.text.trim(),
        audience: _audience,
        description: _noticeController.text.trim(),
        validFrom: _validFrom,
        validUntil: _validUntil,
        mode: _mode,
        linkUrl: linkUrl,
        linkTitle: linkTitle.isNotEmpty ? linkTitle : null,
      );

      final id = await widget.parser.saveDistribution(draft);
      for (final file in _pendingFiles) {
        final path = file.path;
        if (path == null) continue;
        final bytes = await File(path).readAsBytes();
        await widget.parser.uploadFile(
          id,
          fileName: file.name,
          bytes: bytes,
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.fileDistributionAdminSaved)),
      );
      widget.onSaved(id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _audienceLabel(AppLocalizations l10n, DistributionAudience audience) =>
      switch (audience) {
        DistributionAudience.students =>
          l10n.fileDistributionAdminAudienceStudents,
        DistributionAudience.parents =>
          l10n.fileDistributionAdminAudienceParents,
        DistributionAudience.studentsAndParents =>
          l10n.fileDistributionAdminAudienceStudentsAndParents,
        DistributionAudience.teachers =>
          l10n.fileDistributionAdminAudienceTeachers,
      };

  String _modeLabel(AppLocalizations l10n, DistributionMode mode) =>
      switch (mode) {
        DistributionMode.sharedFiles => l10n.fileDistributionAdminModeShared,
        DistributionMode.randomSingle => l10n.fileDistributionAdminModeRandom,
        DistributionMode.textOnly => l10n.fileDistributionAdminModeTextOnly,
        DistributionMode.placeholder =>
          l10n.fileDistributionAdminModePlaceholder,
      };

  Widget _buildFormBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleText = _isEditing
        ? l10n.fileDistributionAdminEditTitle
        : l10n.fileDistributionAdminNewTitle;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.embeddedInSplitView) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titleText,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : widget.onCancel,
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.save),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.fileDistributionAdminFieldTitle,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.fileDistributionAdminFieldTitleRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noticeController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.fileDistributionAdminFieldNotice,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.fileDistributionAdminFieldAudience,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final a in DistributionAudience.values)
                  ChoiceChip(
                    label: Text(_audienceLabel(l10n, a)),
                    selected: _audience == a,
                    onSelected: (_) => setState(() => _audience = a),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.fileDistributionAdminFieldValidity,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: true),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      '${l10n.fileDistributionAdminValidFrom}: ${_dateFormat.format(_validFrom)}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: false),
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      '${l10n.fileDistributionAdminValidUntil}: ${_dateFormat.format(_validUntil)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.fileDistributionAdminFieldMode,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in DistributionMode.values)
                  ChoiceChip(
                    label: Text(_modeLabel(l10n, m)),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ],
            ),
            if (_mode != DistributionMode.textOnly) ...[
              const SizedBox(height: 16),
              Text(
                l10n.fileDistributionAdminFieldFiles,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _pendingFiles.length; i++)
                    InputChip(
                      label: Text(_pendingFiles[i].name),
                      onDeleted: () => setState(() => _pendingFiles.removeAt(i)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.attach_file, size: 18),
                    label: Text(l10n.fileDistributionAdminAddFiles),
                    onPressed: _pickFiles,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.fileDistributionAdminFieldLinkUrl,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _linkTitleController,
              decoration: InputDecoration(
                labelText: l10n.fileDistributionAdminFieldLinkTitle,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInSplitView) {
      return _buildFormBody(context);
    }
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : widget.onCancel,
        ),
        title: Text(
          _isEditing
              ? l10n.fileDistributionAdminEditTitle
              : l10n.fileDistributionAdminNewTitle,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ),
        ],
      ),
      body: _buildFormBody(context),
    );
  }
}
