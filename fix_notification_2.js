const fs = require('fs');
const path = './lib/services/notification_service.dart';

let content = fs.readFileSync(path, 'utf8');

// Just doing simple replace again
content = content.replace(/body:\s*.*?/g, (match) => {
  if (match.includes('remaining')) return "body: '\\ - \\ remaining'";
  return "body: 'Did you arrive safely at \\'";
});

content = content.replace(/await _flutterLocalNotificationsPlugin\.cancel\(id: 888\);/, "await _flutterLocalNotificationsPlugin.cancel(888);");
content = content.replace(/await _flutterLocalNotificationsPlugin\.cancel\(id: 999\);/, "await _flutterLocalNotificationsPlugin.cancel(999);");
content = content.replace(/await _flutterLocalNotificationsPlugin\.show\(id:/g, "await _flutterLocalNotificationsPlugin.show(");
content = content.replace(/, title:/g, ", ");
content = content.replace(/, body:/g, ", ");

// Wait, I am confused about the signature.
fs.writeFileSync(path, content, 'utf8');
