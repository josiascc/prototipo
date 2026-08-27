import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
}

class CustomCard extends StatelessWidget {
  final String? title;
  final List<DetailItem> items;

  const CustomCard({
    Key? key,
    this.title,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.isNotEmpty) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const Divider(thickness: 1.5),
              const SizedBox(height: 8),
            ],
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(item.icon, color: AppTheme.primaryGreen, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        '${item.label}:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 15,
                            color: item.valueColor ?? Colors.black54,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}