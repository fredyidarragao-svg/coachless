import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/health_service.dart';
import 'calendar_screen.dart';
import 'diet_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'sheets.dart';
import 'train_screen.dart';
import '../widgets/ui.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWatch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _syncWatch();
  }

  /// Al abrir la app se leen los datos del día desde Health Connect / Apple Salud.
  Future<void> _syncWatch() async {
    final st = context.read<AppState>();
    final w = st.profile?.watch;
    if (w == null || !(w.route == 'hc' || w.route == 'hk')) return;
    final d = await HealthService.today(w.model ?? '');
    if (d != null && mounted) st.update(() => w.data = d);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final tabs = [
      (Icons.fitness_center_rounded, pr.isKid ? 'Misiones' : 'Entreno', const TrainScreen()),
      (Icons.restaurant_rounded, 'Dieta', const DietScreen()),
      (Icons.grid_view_rounded, 'Biblioteca', const LibraryScreen()),
      (Icons.person_rounded, 'Perfil', const ProfileScreen()),
    ];
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: p.acc, child: Text(pr.initials, style: display(context, 18, color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'COACH', style: display(context, 15, color: p.muted)),
                  TextSpan(text: 'LESS', style: display(context, 15, color: p.acc)),
                ])),
                Text(up(context, pr.isKid ? t('¡Hola, {n}!', {'n': pr.firstName}) : t('Hola, {n}', {'n': pr.firstName})), style: display(context, 24), overflow: TextOverflow.ellipsis),
              ])),
              if (pr.isKid)
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFFC93C), borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0xFFD99A00), offset: Offset(0, 4))]), child: Text('⭐ ${st.totalStars}', style: display(context, 18, color: const Color(0xFF5A3A00))))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
                  child: Row(children: [Icon(Icons.local_fire_department_rounded, size: 16, color: p.acc2), const SizedBox(width: 4), Text('${st.streak}', style: TextStyle(color: p.acc2, fontWeight: FontWeight.w800))]),
                ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
                  child: Icon(Icons.calendar_month_rounded, size: 18, color: p.fg),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => showSheet(context, (_) => LanguageSheet(onPick: st.setLang)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
                  child: Row(children: [Icon(Icons.language_rounded, size: 16, color: p.fg), const SizedBox(width: 4), Text(pr.lang.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))]),
                ),
              ),
            ]),
          ),
          Expanded(child: tabs[st.tab].$3),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
        padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => st.setTab(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: st.tab == i ? p.acc : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tabs[i].$1, color: st.tab == i ? Colors.white : p.muted),
                    const SizedBox(height: 3),
                    Text(t(tabs[i].$2), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: st.tab == i ? Colors.white : p.muted)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

