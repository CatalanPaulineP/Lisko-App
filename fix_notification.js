const fs = require('fs');
const path = './lib/services/notification_service.dart';

let content = fs.readFileSync(path, 'utf8');

content = content.replace(
  /await _flutterLocalNotificationsPlugin\.initialize\([\s\S]*?\);/,
  'await _flutterLocalNotificationsPlugin.initialize(initializationSettings: initializationSettings);'
);

content = content.replace(
  /await _flutterLocalNotificationsPlugin\.show\(\s*888,[\s\S]*?\);/,
  'await _flutterLocalNotificationsPlugin.show(id: 888, title: "LisKo: 🚶 Travel Timer", body: ${destination} -  remaining, notificationDetails: notificationDetails);'
);

content = content.replace(
  /await _flutterLocalNotificationsPlugin\.show\(\s*999,[\s\S]*?\);/,
  'await _flutterLocalNotificationsPlugin.show(id: 999, title: "Arrival Check", body: Did you arrive safely at ?, notificationDetails: notificationDetails);'
);

content = content.replace(
  /await _flutterLocalNotificationsPlugin\.cancel\(\s*888\s*\);/,
  'await _flutterLocalNotificationsPlugin.cancel(id: 888);'
);

content = content.replace(
  /await _flutterLocalNotificationsPlugin\.cancel\(\s*999\s*\);/,
  'await _flutterLocalNotificationsPlugin.cancel(id: 999);'
);

fs.writeFileSync(path, content, 'utf8');
