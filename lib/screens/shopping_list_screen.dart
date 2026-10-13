import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/stores_service.dart';
import '../widgets/ui.dart';

/// Lista de mercado de la semana: suma los ingredientes de todos los menús (lunes a domingo)
/// para hacer una sola compra.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  String _asText(WeekShopping w, Profile p) {
    final b = StringBuffer('🛒 ${t('Lista de mercado de la semana')} (${I18n.dateLong(dparse(w.start))} – ${I18n.dateLong(dparse(w.end))})\n');
    w.byAisle.forEach((aisle, lines) {
      b.writeln('\n*${t(aisle)}*');
      for (final l in lines) {
        b.writeln('▫️ ${l.product} — ${l.amount}');
      }
    });
    b.writeln('\n${t('Costo estimado')}: ${money(w.costCop, p)} (${storeOf(p).name})');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final w = weeklyShopping(pr, st.selected, (d) => st.peek(d)?.meals ?? const {});
    final store = storeOf(pr);
    final checkedKey = (ShopLine l) => '${w.start}|${l.key}';
    final done = w.byAisle.values.expand((e) => e).where((l) => st.shopChecked.contains(checkedKey(l))).length;
    final stores = storesFor(pr);
    final base = w.costCop / store.priceFactor;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(t('Lista de mercado'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        HeroBox(children: [
          Eyebrow('${I18n.dateLong(dparse(w.start))} – ${I18n.dateLong(dparse(w.end))}', color: Colors.white),
          Text(up(context, t('Una sola compra para tu semana')), style: display(context, 30, color: Colors.white)),
          statRow([
            StatTile('${w.count}', t('productos'), onHero: true),
            StatTile('${w.meals}', t('comidas'), onHero: true),
            StatTile('$done/${w.count}', t('en el carrito'), onHero: true),
          ]),
          Text('${t('Costo estimado')}: ${money(w.costCop, pr)} · ${store.name}', style: display(context, 22, color: Colors.white)),
          Row(children: [
            Expanded(child: Btn(t('Copiar lista'), icon: Icons.copy_rounded, onTap: () async {
              await Clipboard.setData(ClipboardData(text: _asText(w, pr)));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Lista copiada'))));
            })),
            const SizedBox(width: 10),
            Expanded(child: Btn(t('Enviar por WhatsApp'), icon: Icons.send_rounded, onTap: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_asText(w, pr))}'), mode: LaunchMode.externalApplication))),
          ]),
        ]),
        const SizedBox(height: 14),
        Box(child: vgap([
          Text(t('¿Dónde sale más barato?'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          for (final s in (List.of(stores)..sort((a, b) => a.priceFactor.compareTo(b.priceFactor))).take(5))
            InkWell(
              onTap: () => st.update(() => pr.store = s.name),
              child: Row(children: [
                Icon(s.name == store.name ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: s.name == store.name ? p.acc : p.muted, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${s.name} · ${I18n.fmt(s.km)} km', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(money(base * s.priceFactor, pr), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          Text(t('Valores estimados. Toca un producto para ver su precio real en la web del supermercado.'), style: TextStyle(color: p.muted, fontSize: 12)),
        ], 10)),
        for (final e in w.byAisle.entries) ...[
          const SizedBox(height: 18),
          SectionTitle(t(e.key), trailing: Text('${e.value.length}', style: TextStyle(color: p.muted))),
          const SizedBox(height: 8),
          Box(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(children: [
              for (final l in e.value)
                Row(children: [
                  Checkbox(value: st.shopChecked.contains(checkedKey(l)), activeColor: p.ok, onChanged: (_) => st.toggleShop(checkedKey(l))),
                  Expanded(
                    child: Text(l.product,
                        style: TextStyle(fontWeight: FontWeight.w600, decoration: st.shopChecked.contains(checkedKey(l)) ? TextDecoration.lineThrough : null, color: st.shopChecked.contains(checkedKey(l)) ? p.muted : p.fg)),
                  ),
                  Text(l.amount, style: TextStyle(color: p.acc2, fontWeight: FontWeight.w800)),
                  IconButton(
                    tooltip: t('Ver precio'),
                    icon: Icon(Icons.sell_outlined, size: 18, color: p.muted),
                    onPressed: () => launchUrl(StoresService.priceSearch(l.product, NearbyStore(name: store.name, km: 0, website: store.website)), mode: LaunchMode.externalApplication),
                  ),
                ]),
            ]),
          ),
        ],
      ]),
    );
  }
}
