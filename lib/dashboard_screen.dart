import 'package:flutter/material.dart';
import 'package:phonefixer_shop/add_parts_screen.dart';
import 'package:phonefixer_shop/customer_add.dart';
import 'package:phonefixer_shop/predfined_screen.dart';
import 'package:phonefixer_shop/report_screen.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 3 / 2,
          ),
          children: [
            _buildDashboardCard(
              context,
              title: 'Sale History',
              icon: Icons.history,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SalesListScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Customers',
              icon: Icons.people,
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CustomerManagementScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Add Model',
              icon: Icons.add,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddModelScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Predefined Parts',
              icon: Icons.build,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PredefinedPartsScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Reports',
              icon: Icons.insert_chart,
              color: Colors.redAccent,
              onTap: () {
                // Add navigation to ReportsScreen here
              },
            ),
            _buildDashboardCard(
              context,
              title: 'Settings',
              icon: Icons.settings,
              color: Colors.teal,
              onTap: () {
                // Add navigation to SettingsScreen here
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
