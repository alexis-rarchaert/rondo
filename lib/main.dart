import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/checklist_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/route_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  // Masque la barre de navigation système (garde la barre de statut) sur
  // toutes les pages de l'app.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Ma Tournée',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: buildTheme(AppColors.light, Brightness.light),
        darkTheme: buildTheme(AppColors.dark, Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tabIndex = 0;
  final _dowFmt = DateFormat('EEEE d MMMM', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final app = context.watch<AppState>();
    final date = DateTime.parse('${app.currentDay}T12:00:00');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              app.data.tourneeName,
              style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              _dowFmt.format(date),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: colors.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(date.year - 1),
                lastDate: DateTime(date.year + 1),
              );
              if (picked != null && context.mounted) {
                context.read<AppState>().setDay(todayKey(picked));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !app.loaded
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: tabIndex,
              children: const [RouteScreen(), ChecklistScreen(), NotesScreen()],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) => setState(() => tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.push_pin_outlined), selectedIcon: Icon(Icons.push_pin), label: 'Tournée'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'Notes'),
        ],
      ),
    );
  }
}
