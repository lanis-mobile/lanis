import 'package:liblanis/liblanis.dart';

TypedSettings? timetableSettingsForPupil(
  TypedSettings? settings,
  String pupilId,
) => settings?.scoped('timetable-pupil/${Uri.encodeComponent(pupilId)}/');
