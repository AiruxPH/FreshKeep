import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'guidance_screen.dart';
import 'inventory_screen.dart';
import 'reminder_screen.dart';
import 'reminders/reminder_controller.dart';
import 'report_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.database, this.reminders});
  final InventoryDatabase database;
  final ReminderController? reminders;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  int _inventoryRevision = 0;
  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = index;
      if (index == 0) _inventoryRevision++;
    });
  }

  static const _labels = ['Inventory', 'Dashboard', 'Waste', 'More'];
  static const _icons = [
    Icons.kitchen_outlined,
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.more_horiz,
  ];

  Widget _pages() => IndexedStack(
    index: _selected,
    children: [
      ScaffoldMessenger(
        child: InventoryScreen(
          database: widget.database,
          reminders: widget.reminders,
          refreshToken: _inventoryRevision,
        ),
      ),
      _selected == 1
          ? ReportScreen(database: widget.database)
          : const SizedBox(),
      _selected == 2
          ? ReportScreen(database: widget.database, wasteLog: true)
          : const SizedBox(),
      _more(),
    ],
  );

  Widget _more() => Scaffold(
    appBar: AppBar(title: const Text('More')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Make FreshKeep yours',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Helpful references and settings, all in one place.'),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Reminders'),
                    subtitle: const Text('Choose when to review food dates'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReminderScreen(
                          database: widget.database,
                          controller: widget.reminders,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Storage guidance'),
                    subtitle: const Text(
                      'Find food storage references and sources',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GuidanceScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.offline_pin_outlined),
              title: Text('Your kitchen, saved locally'),
              subtitle: Text('Your inventory stays on this device.'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 1000) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selected,
                onDestinationSelected: _select,
                extended: true,
                minExtendedWidth: 210,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_outlined),
                      SizedBox(width: 8),
                      Text(
                        'FreshKeep',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(_icons[i]),
                      label: Text(_labels[i]),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _pages()),
            ],
          ),
        );
      }
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
      return Scaffold(
        body: _pages(),
        bottomNavigationBar: largeText
            ? SafeArea(
                top: false,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Wrap(
                    children: [
                      for (var i = 0; i < _labels.length; i++)
                        SizedBox(
                          width: constraints.maxWidth / 2,
                          child: TextButton.icon(
                            onPressed: () => _select(i),
                            icon: Icon(_icons[i]),
                            label: Text(_labels[i]),
                            style: TextButton.styleFrom(
                              backgroundColor: _selected == i
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: _select,
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i]),
                      label: _labels[i],
                      tooltip: _labels[i],
                    ),
                ],
              ),
      );
    },
  );
}
