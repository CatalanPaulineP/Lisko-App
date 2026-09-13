import re

with open('lib/screens/active_trip_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace the corrupted SOS button label
content = content.replace("'dYs\" Need Help / SOS'", "'Need Help / SOS'")
content = content.replace("'dYs\" Need Help'", "'Need Help / SOS'")

# 2. Replace corrupted Arrived text
content = content.replace("'● Arrived'", "'Arrived'")

# 3. Replace corrupted Active text (and convert it into a Row with an icon for better UI, matching my previous successful edit)
active_badge_old = """      child: const Text(
        '● Active',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.successText,
        ),
      ),"""

active_badge_new = """      child: Row(
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
      ),"""
content = content.replace(active_badge_old, active_badge_new)


# 4. Replace the Top Header to match the requested Solid Navy design
top_header_old = """          Row(
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
          ),"""

top_header_new = """          Container(
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
                      'Destination: $destination',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${totalDuration.inMinutes} min',
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
          ),"""
content = content.replace(top_header_old, top_header_new)

with open('lib/screens/active_trip_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

