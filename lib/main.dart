import 'package:flutter/material.dart';

import 'data/inventory_database.dart';
import 'app_shell.dart';
import 'intro/freshkeep_entry_gate.dart';
import 'widgets/local_day_scope.dart';
import 'reminders/reminder_controller.dart';
import 'reminders/notification_service.dart';
import 'reminders/reminder_lifecycle.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = InventoryDatabase();
  runApp(
    FreshKeepApp(
      database: database,
      reminders: ReminderController(database, createNotificationService()),
      showIntro: true,
    ),
  );
}

class FreshKeepApp extends StatelessWidget {
  const FreshKeepApp({
    super.key,
    required this.database,
    this.reminders,
    this.showIntro = false,
  });
  final InventoryDatabase database;
  final ReminderController? reminders;
  final bool showIntro;
  @override
  Widget build(BuildContext context) => LocalDayScope(
    child: ReminderLifecycle(
      controller: reminders,
      child: MaterialApp(
        title: 'FreshKeep',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28664B)),
          scaffoldBackgroundColor: const Color(0xFFF7F8F3),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F8F3),
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE0E6DF)),
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Color(0xFFDDECE1),
            height: 76,
          ),
          navigationRailTheme: const NavigationRailThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Color(0xFFDDECE1),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF28664B),
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            filled: true,
            fillColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        home: FreshKeepEntryGate(
          showIntro: showIntro,
          child: AppShell(database: database, reminders: reminders),
        ),
      ),
    ),
  );
}
