import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/applets/conversations/conversations_nav.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Unified contact info for a teacher from Study Groups or Lessons.
class TeacherContact {
  final String displayName;
  final String receiverName;
  final String? conversationReceiverId;
  final String? email;

  const TeacherContact({
    required this.displayName,
    required this.receiverName,
    this.conversationReceiverId,
    this.email,
  });

  factory TeacherContact.fromStudyGroupTeacher(
    StudentStudyGroupTeacher teacher,
  ) {
    final nameParts = [
      teacher.lastName.trim(),
      teacher.firstName.trim(),
    ].where((p) => p.isNotEmpty).join(', ');
    final krz = teacher.krz.trim();
    final display = nameParts.isNotEmpty
        ? (krz.isNotEmpty ? '$nameParts ($krz)' : nameParts)
        : krz;
    return TeacherContact(
      displayName: display,
      receiverName: display,
      conversationReceiverId: teacher.conversationReceiverId,
      email: teacher.email,
    );
  }

  factory TeacherContact.fromLessonTeacher(LessonTeacher teacher) {
    final name = teacher.teacher?.trim() ?? '';
    final krz = teacher.teacherKuerzel?.trim() ?? '';
    final display = name.isNotEmpty
        ? (krz.isNotEmpty ? '$name ($krz)' : name)
        : krz;
    final receiver = name.isNotEmpty ? name : krz;
    return TeacherContact(
      displayName: display,
      receiverName: receiver,
      conversationReceiverId: teacher.conversationReceiverId,
      email: teacher.email,
    );
  }

  bool get hasConversation =>
      conversationReceiverId != null && conversationReceiverId!.isNotEmpty;

  bool get hasEmail => email != null && email!.isNotEmpty;

  bool hasAnyAction({required bool allowConversations}) =>
      (allowConversations && hasConversation) || hasEmail;
}

/// Whether the active session supports the Conversations applet.
bool doesSessionSupportConversations(WidgetRef ref) {
  return ref
          .watch(sessionProvider)
          .asData
          ?.value
          ?.doesSupportFeature(Applets.conversations) ??
      false;
}

/// Opens the Conversations compose flow prefilled with [teacher].
void openTeacherMessage(BuildContext context, TeacherContact teacher) {
  final id = teacher.conversationReceiverId;
  if (id == null || id.isEmpty) return;
  openComposeConversation(
    context,
    receivers: [ReceiverEntry(id, teacher.receiverName, true)],
  );
}

/// Launches the external mail client for [email].
Future<void> launchTeacherEmail(BuildContext context, String email) async {
  final Uri emailLaunchUri = Uri(scheme: 'mailto', path: email);
  await safeLaunchUrl(
    emailLaunchUri,
    context: context,
    mode: LaunchMode.externalApplication,
  );
}

/// Shows a Material 3 modal bottom sheet listing message/email actions for one
/// or more [teachers]. Does nothing if no teacher has an available action.
Future<void> showTeacherContactSheet(
  BuildContext context, {
  String? courseTitle,
  required List<TeacherContact> teachers,
  required bool allowConversations,
}) async {
  final actionable = [
    for (final teacher in teachers)
      if (teacher.hasAnyAction(allowConversations: allowConversations)) teacher,
  ];
  if (actionable.isEmpty) return;

  await showRootModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;

      Widget buildActionTile({
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
        return Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Icon(icon, size: 20),
            ),
            title: Text(title),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: onTap,
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (courseTitle != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  courseTitle,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (var i = 0; i < actionable.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  actionable[i].displayName,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (allowConversations && actionable[i].hasConversation) ...[
                buildActionTile(
                  icon: Icons.chat_bubble_outline,
                  title: l10n.sendMessage,
                  subtitle: l10n.openInConversations,
                  onTap: () {
                    final teacher = actionable[i];
                    Navigator.pop(sheetContext);
                    if (context.mounted) {
                      openTeacherMessage(context, teacher);
                    }
                  },
                ),
                if (actionable[i].hasEmail) const SizedBox(height: 8),
              ],
              if (actionable[i].hasEmail)
                buildActionTile(
                  icon: Icons.email_outlined,
                  title: l10n.sendEmail,
                  subtitle: actionable[i].email!,
                  onTap: () {
                    final email = actionable[i].email!;
                    Navigator.pop(sheetContext);
                    if (context.mounted) {
                      launchTeacherEmail(context, email);
                    }
                  },
                ),
            ],
          ],
        ),
      );
    },
  );
}
