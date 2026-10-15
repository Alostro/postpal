import 'package:flutter/material.dart';

import 'screens/edit_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/remind_screen.dart';
import 'screens/shoot_screen.dart';
import 'screens/write_screen.dart';
import 'services/notifications.dart';
import 'services/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.load();
  await Notifications.instance.init();
  runApp(const PostPalApp());
}

class PostPalApp extends StatelessWidget {
  const PostPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFD9466F);
    return MaterialApp(
      title: 'PostPal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      PlanScreen(onWriteCaption: () => _goTo(3)),
      const ShootScreen(),
      const EditScreen(),
      WriteScreen(onAddedToPlan: () => _goTo(0)),
      const RemindScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Plan'),
          NavigationDestination(
              icon: Icon(Icons.videocam_outlined),
              selectedIcon: Icon(Icons.videocam),
              label: 'Shoot'),
          NavigationDestination(
              icon: Icon(Icons.auto_fix_high_outlined),
              selectedIcon: Icon(Icons.auto_fix_high),
              label: 'Edit'),
          NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: 'Write'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Remind'),
        ],
      ),
    );
  }
}
