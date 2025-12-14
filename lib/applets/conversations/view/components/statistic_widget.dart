import 'package:flutter/material.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/models/conversations.dart';

class StatisticWidget extends StatelessWidget {
  final String conversationTitle;
  final ParticipationStatistics statistics;

  const StatisticWidget({
    super.key,
    required this.statistics,
    required this.conversationTitle,
  });

  Widget statisticsHeaderRow(
    BuildContext context,
    Icon icon,
    String title,
    int count,
  ) {
    return Column(
      children: [
        icon,
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(count.toString(), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).receivers)),
      body: ListView(
        children: [
          const SizedBox(height: 30),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.groups_outlined, size: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  conversationTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: statisticsHeaderRow(
                      context,
                      const Icon(Icons.person),
                      AppLocalizations.of(context).participants,
                      statistics.countStudents,
                    ),
                  ),
                  Expanded(
                    child: statisticsHeaderRow(
                      context,
                      const Icon(Icons.school),
                      AppLocalizations.of(context).supervisors,
                      statistics.countTeachers,
                    ),
                  ),
                  Expanded(
                    child: statisticsHeaderRow(
                      context,
                      const Icon(Icons.supervisor_account),
                      AppLocalizations.of(context).parents,
                      statistics.countParents,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            AppLocalizations.of(context).knownReceivers,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          for (final KnownParticipant participant
              in statistics.knownParticipants) ...[
            ListTile(
              title: Text(participant.name),
              leading: Icon(participant.type.icon),
            ),
          ],
        ],
      ),
    );
  }
}
