import 'dart:io';

final Map<String, dynamic> kvDefaults = {
  "notifications-target-interval-minutes": 30,
  "notifications-allowed-days": [true, true, true, true, true, false, false],
  "notifications-start-time": Platform.isIOS ? [5, 30] : [6, 30],
  "notifications-end-time": Platform.isIOS ? [16, 30] : [15, 0],
  "last-app-version": "0.0.0",
  "color": "standard",
  "theme": "system",
  "is-amoled": false,
};
