import 'package:lanis/generated/l10n.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

/// Compact AppBar popover switcher for multi-version timetables
/// (multiple "Gültig ab" plans or weekly Davinci views).
///
/// Renders nothing when [versions] has fewer than 2 entries.
class TimetableVersionButton extends StatelessWidget {
  final List<TimetableVersion> versions;
  final String? selectedDate;
  final String? defaultDate;
  final bool compact;
  final bool Function(TimetableVersion version)? isVersionEnabled;
  final ValueChanged<TimetableVersion> onSelected;

  const TimetableVersionButton({
    super.key,
    required this.versions,
    required this.selectedDate,
    this.defaultDate,
    this.compact = false,
    this.isVersionEnabled,
    required this.onSelected,
  });

  TimetableVersion? get _activeVersion {
    if (selectedDate != null && selectedDate!.isNotEmpty) {
      for (final v in versions) {
        if (v.date == selectedDate) return v;
      }
    }
    for (final v in versions) {
      if (v.isSelected) return v;
    }
    return versions.isNotEmpty ? versions.first : null;
  }

  /// Shortens verbose portal labels like `"ab 23.11.2026 (bis 10.12.2026)"`
  /// for the AppBar pill while keeping the full label inside the popover menu.
  static String formatPillLabel(TimetableVersion version, {bool compact = false}) {
    final raw = version.label.trim();
    if (raw.isEmpty) return version.date;
    // Strip parenthetical end-date suffix for the pill (full range is in popover).
    final withoutParen = raw.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
    final base = withoutParen.isNotEmpty ? withoutParen : raw;
    if (!compact) return base;
    // In compact mode, shorten "ab DD.MM.YYYY" -> "ab DD.MM."
    return base.replaceFirstMapped(
      RegExp(r'^ab\s+(\d{2}\.\d{2}\.)\d{4}$'),
      (m) => 'ab ${m.group(1)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (versions.length < 2) return const SizedBox.shrink();

    final active = _activeVersion;
    if (active == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isAlternate =
        defaultDate != null &&
        defaultDate!.isNotEmpty &&
        active.date != defaultDate;

    final pillBg = isAlternate
        ? cs.tertiaryContainer
        : cs.surfaceContainerHighest;
    final pillFg = isAlternate
        ? cs.onTertiaryContainer
        : cs.onSurface;
    final pillBorder = isAlternate
        ? cs.tertiary.withValues(alpha: 0.45)
        : cs.outlineVariant;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      menuChildren: [
        for (final version in versions)
          Builder(
            builder: (context) {
              final enabled = isVersionEnabled?.call(version) ?? true;
              final isSelected = version.date == active.date;
              final textColor = !enabled
                  ? cs.onSurface.withValues(alpha: 0.38)
                  : isSelected
                  ? cs.primary
                  : cs.onSurface;
              return MenuItemButton(
                onPressed: enabled ? () => onSelected(version) : null,
                leadingIcon: isSelected
                    ? Icon(Icons.check, size: 18, color: textColor)
                    : const SizedBox(width: 18),
                child: Text(
                  version.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: textColor,
                  ),
                ),
              );
            },
          ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: l10n.timetableVersionTooltip,
          child: Material(
            color: pillBg,
            shape: StadiumBorder(side: BorderSide(color: pillBorder)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: pillFg,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: compact ? 92 : 148),
                      child: Text(
                        formatPillLabel(active, compact: compact),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: pillFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      controller.isOpen
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      size: 18,
                      color: pillFg,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
