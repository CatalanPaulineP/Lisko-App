import 'dart:io';

void main() {
  final file = File('lib/screens/active_trip_screen.dart');
  String content = file.readAsStringSync();

  // 1. Top header replacement
  final topHeaderOld = '''          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRIP IN PROGRESS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.body,
                    ),
                  ),
                  Text(
                    destination,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.header,
                    ),
                  ),
                  Text(
                    formatTripDuration(totalDuration),
                    style: const TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                ],
              ),
              const ActiveBadge(),
            ],
          ),''';
  final topHeaderNew = '''          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.header,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination: \$destination',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: \${totalDuration.inMinutes} min',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const ActiveBadge(),
              ],
            ),
          ),''';

  content = content.replaceAll(topHeaderOld, topHeaderNew);

  // 2. Corrupt strings replacement
  content = content.replaceAll(RegExp(r"'[^']*Need Help / SOS'"), "'Need Help / SOS'");
  content = content.replaceAll(RegExp(r"'[^']*Need Help'"), "'Need Help / SOS'");
  
  // Replace anything that looks like "-? Active" inside the ActiveBadge with a proper Row
  final activeBadgeOldRegex = RegExp(r"child:\s*const\s*Text\(\s*'[^']*Active',\s*style:\s*TextStyle\(\s*fontSize:\s*12,\s*fontWeight:\s*FontWeight\.w800,\s*color:\s*AppColors\.successText,\s*\),\s*\),", multiLine: true);
  final activeBadgeNew = '''child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.directions_run_rounded, size: 14, color: AppColors.successText),
          SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.successText,
            ),
          ),
        ],
      ),''';
  
  content = content.replaceAll(activeBadgeOldRegex, activeBadgeNew);

  // Arrived
  content = content.replaceAll(RegExp(r"'[^']*Arrived'"), "'Arrived'");

  file.writeAsStringSync(content);
}

