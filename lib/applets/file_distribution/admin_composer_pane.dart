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
  final VoidCallback? onDirtyCancel;
  final ValueChanged<int> onSaved;

  const AdminComposerPane({
    super.key,
    required this.parser,
    this.initialDetail,
    this.embeddedInSplitView = false,
    required this.onCancel,
    this.onDirtyCancel,
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
  int? _savedId;
  bool _saving = false;

  bool get _isEditing => widget.initialDetail != null || _savedId != null;

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
    if (picked == null || !mounted) return;
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
    if (files.isEmpty || !mounted) return;
    setState(() {
      _pendingFiles.addAll(files.where((f) => f.path != null));
    });
  }

  void _handleCancel() {
    if (_savedId != null && widget.onDirtyCancel != null) {
      widget.onDirtyCancel!();
    } else {
      widget.onCancel();
    }
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
      final initial = widget.initialDetail;

      final draft = FileDistributionDraft(
        id: initial?.id ?? _savedId,
        title: _titleController.text.trim(),
        audience: _audience,
        gradeFrom: initial?.gradeFrom,
        gradeUntil: initial?.gradeUntil,
        description: _noticeController.text.trim(),
        validFrom: _validFrom,
        validUntil: _validUntil,
        mode: _mode,
        fileNameTemplate: initial != null && initial.fileNameTemplates.isNotEmpty
            ? initial.fileNameTemplates.first
            : null,
        startNumber: initial?.startNumber,
        linkUrl: linkUrl,
        linkTitle: linkUrl != null && linkTitle.isNotEmpty ? linkTitle : null,
      );

      final id = await widget.parser.saveDistribution(draft);
      _savedId = id;

      final failedFiles = <String>[];
      if (_mode == DistributionMode.textOnly) {
        _pendingFiles.clear();
      } else {
        while (_pendingFiles.isNotEmpty) {
          final file = _pendingFiles.first;
          final path = file.path;
          if (path == null) {
            _pendingFiles.removeAt(0);
            continue;
          }
          final bytes = await File(path).readAsBytes();
          final ok = await widget.parser.uploadFile(
            id,
            fileName: file.name,
            bytes: bytes,
          );
          if (ok) {
            if (mounted) {
              setState(() => _pendingFiles.removeAt(0));
            } else {
              _pendingFiles.removeAt(0);
            }
          } else {
            failedFiles.add(file.name);
            break;
          }
        }
      }

      if (!mounted) return;
      if (failedFiles.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('${l10n.error}: ${failedFiles.first}')),
        );
        return;
      }
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

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 18),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 0,
          ),
        ),
        child: Text(
          _dateFormat.format(value),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleText = _isEditing
        ? l10n.fileDistributionAdminEditTitle
        : l10n.fileDistributionAdminNewTitle;
    final wide = widget.embeddedInSplitView;

    final audienceField = DropdownButtonFormField<DistributionAudience>(
      initialValue: _audience,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.fileDistributionAdminFieldAudience,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final a in DistributionAudience.values)
          DropdownMenuItem(
            value: a,
            child: Text(
              _audienceLabel(l10n, a),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _audience = value);
      },
    );

    final modeField = DropdownButtonFormField<DistributionMode>(
      initialValue: _mode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.fileDistributionAdminFieldMode,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final m in DistributionMode.values)
          DropdownMenuItem(
            value: m,
            child: Text(
              _modeLabel(l10n, m),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _mode = value;
            if (_mode == DistributionMode.textOnly) {
              _pendingFiles.clear();
            }
          });
        }
      },
    );

    final linkUrlField = TextFormField(
      controller: _linkUrlController,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: l10n.fileDistributionAdminFieldLinkUrl,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (text.isEmpty) return null;
        final uri = Uri.tryParse(text);
        if (uri == null ||
            !(uri.scheme == 'http' || uri.scheme == 'https') ||
            uri.host.isEmpty) {
          return l10n.error;
        }
        return null;
      },
    );

    final linkTitleField = TextFormField(
      controller: _linkTitleController,
      decoration: InputDecoration(
        labelText: l10n.fileDistributionAdminFieldLinkTitle,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 20 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) ...[
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
                    onPressed: _saving ? null : _handleCancel,
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
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.fileDistributionAdminFieldTitle,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.fileDistributionAdminFieldTitleRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noticeController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.fileDistributionAdminFieldNotice,
                alignLabelWithHint: true,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (wide)
              Row(
                children: [
                  Expanded(child: audienceField),
                  const SizedBox(width: 12),
                  Expanded(child: modeField),
                ],
              )
            else ...[
              audienceField,
              const SizedBox(height: 12),
              modeField,
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: l10n.fileDistributionAdminValidFrom,
                    value: _validFrom,
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: l10n.fileDistributionAdminValidUntil,
                    value: _validUntil,
                    icon: Icons.event_outlined,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            if (_mode != DistributionMode.textOnly) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < _pendingFiles.length; i++)
                    InputChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(_pendingFiles[i].name),
                      onDeleted: () => setState(() => _pendingFiles.removeAt(i)),
                    ),
                  ActionChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    avatar: const Icon(Icons.attach_file, size: 18),
                    label: Text(l10n.fileDistributionAdminAddFiles),
                    onPressed: _pickFiles,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: linkUrlField),
                  const SizedBox(width: 12),
                  Expanded(child: linkTitleField),
                ],
              )
            else ...[
              linkUrlField,
              const SizedBox(height: 12),
              linkTitleField,
            ],
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
          onPressed: _saving ? null : _handleCancel,
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
