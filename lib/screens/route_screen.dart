import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/osm_route_map.dart';
import 'package_scan_screen.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  bool followMode = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Segmented(
          followMode: followMode,
          colors: colors,
          onChanged: (v) => setState(() => followMode = v),
        ),
        const SizedBox(height: 10),
        _GpsStatus(colors: colors),
        const SizedBox(height: 8),
        if (!followMode) _RecordPanel(colors: colors) else _FollowPanel(colors: colors),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  final bool followMode;
  final AppColors colors;
  final ValueChanged<bool> onChanged;

  const _Segmented({required this.followMode, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? colors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(kRadius),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: active ? colors.accentInk : colors.inkSoft,
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          seg('Enregistrer', !followMode, () => onChanged(false)),
          const SizedBox(width: 3),
          seg('Suivre', followMode, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _GpsStatus extends StatelessWidget {
  final AppColors colors;
  const _GpsStatus({required this.colors});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ok = app.gpsError == null && app.lastPos != null;
    final err = app.gpsError != null;
    String text;
    if (err) {
      text = app.gpsError!;
    } else if (ok) {
      text = 'GPS actif · précision ±${app.lastAccuracy?.round() ?? '?'} m';
    } else {
      text = 'Recherche du signal GPS…';
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: err ? colors.danger : (ok ? colors.live : colors.line),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: err ? colors.danger : colors.inkSoft)),
        ),
      ],
    );
  }
}

class _MapBox extends StatelessWidget {
  final AppColors colors;
  final int? nextStopIndex;
  final bool navigate;
  const _MapBox({required this.colors, this.nextStopIndex, this.navigate = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      height: 340,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: OsmRouteMap(
        track: app.data.route.points,
        stops: app.data.route.stops,
        visited: app.ensureDay(app.currentDay).visited,
        live: app.lastPos,
        heading: app.lastHeading,
        nextStopIndex: nextStopIndex,
        colors: colors,
        navigate: navigate,
        startPoint: app.data.route.startPoint,
        endPoint: app.data.route.endPoint,
        uTurnZone: app.data.route.uTurnZone,
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  final AppColors colors;
  const _RecordPanel({required this.colors});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mins = app.recElapsed.inMinutes;
    final dist = app.recDistance;
    final distText = dist < 1000 ? '${dist.round()} m' : '${(dist / 1000).toStringAsFixed(1)} km';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.paperRaised,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.read<AppState>().toggleRecording(),
                  icon: Icon(app.recording ? Icons.stop_rounded : Icons.fiber_manual_record),
                  label: Text(app.recording ? "Arrêter l'enregistrement" : "Démarrer l'enregistrement"),
                  style: FilledButton.styleFrom(
                    backgroundColor: app.recording ? colors.live : colors.accent,
                    foregroundColor: app.recording ? Colors.white : colors.accentInk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                app.recording
                    ? "Marche normalement, un arrêt est ajouté automatiquement dès que tu t'arrêtes 10 secondes quelque part. Utilise le bouton ci-dessous si besoin de le forcer."
                    : "Démarre l'enregistrement au premier arrêt de ta tournée.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: colors.inkSoft),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Stat(label: 'Parcouru', value: distText, colors: colors),
                  const SizedBox(width: 18),
                  _Stat(label: 'Durée', value: '$mins min', colors: colors),
                  const SizedBox(width: 18),
                  _Stat(label: 'Arrêts', value: '${app.data.route.stops.length}', colors: colors),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Opacity(
                  opacity: app.recording && app.lastPos != null ? 1 : 0.45,
                  child: OutlinedButton.icon(
                    onPressed: app.recording && app.lastPos != null ? () => _markStop(context) : null,
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: const Text('Marquer un arrêt ici'),
                  ),
                ),
              ),
              if (!(app.recording && app.lastPos != null)) ...[
                const SizedBox(height: 6),
                Text(
                  !app.recording ? "Démarre l'enregistrement pour pouvoir marquer un arrêt" : 'En attente du signal GPS…',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: colors.inkSoft, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        _MapBox(colors: colors),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ARRÊTS ENREGISTRÉS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: colors.inkSoft)),
            _CountPill(text: '${app.data.route.stops.length}', colors: colors),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PackageScanScreen()),
            ),
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: const Text('Scanner des colis'),
          ),
        ),
        if (app.data.route.stops.length >= 3) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmOptimize(context),
              icon: const Icon(Icons.alt_route_outlined, size: 18),
              label: const Text("Optimiser l'ordre des arrêts"),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (app.data.route.stops.isEmpty)
          _Empty(
            colors: colors,
            text: "Aucun arrêt marqué pour l'instant. Utilise le bouton ci-dessus pendant que tu marches avec ton collègue.",
          )
        else
          ...List.generate(app.data.route.stops.length, (i) {
            final s = app.data.route.stops[i];
            return _RowCard(
              colors: colors,
              leading: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.inkSoft)),
              title: stopDisplayLabel(s, i),
              subtitle: s.note.isNotEmpty ? s.note : null,
              trailing: IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.inkSoft),
                onPressed: () => context.read<AppState>().deleteStop(i),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _confirmOptimize(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Optimiser l'ordre des arrêts"),
        content: const Text(
          "Réorganise les arrêts pour minimiser la distance à parcourir, "
          "en partant du premier arrêt enregistré. L'ordre actuel sera remplacé.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Optimiser')),
        ],
      ),
    );
    if (ok == true && context.mounted) context.read<AppState>().optimizeStops();
  }

  Future<void> _markStop(BuildContext context) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvel arrêt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'digicode, chien, LRAR… (optionnel)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (note == null) return;
    if (context.mounted) context.read<AppState>().markStop(note.trim());
  }
}

class _StreetHeader extends StatelessWidget {
  final String? street;
  final String? turnInstruction;
  final AppColors colors;
  const _StreetHeader({required this.street, required this.colors, this.turnInstruction});

  IconData get _icon {
    final t = turnInstruction;
    if (t == null) return Icons.navigation_outlined;
    if (t.contains('droite')) return Icons.turn_right;
    if (t.contains('gauche')) return Icons.turn_left;
    if (t.contains('tout droit')) return Icons.straight;
    return Icons.navigation_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          Icon(_icon, color: colors.accentInk, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  turnInstruction ?? (street ?? 'Localisation en cours…'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: colors.accentInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (turnInstruction != null && street != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    street!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.accentInk.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowPanel extends StatelessWidget {
  final AppColors colors;
  const _FollowPanel({required this.colors});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stops = app.data.route.stops;
    final day = app.ensureDay(app.currentDay);

    if (stops.isEmpty) {
      return Column(
        children: [
          _StreetHeader(street: app.currentStreet, turnInstruction: app.nextTurnInstruction, colors: colors),
          const SizedBox(height: 10),
          _MapBox(colors: colors, navigate: true),
          const SizedBox(height: 16),
          _Empty(
            colors: colors,
            text: "Aucune tournée enregistrée pour l'instant. Passe en mode Enregistrer pendant ta doublure pour créer le tracé.",
          ),
        ],
      );
    }

    final undoneIdx = <int>[];
    for (var i = 0; i < stops.length; i++) {
      if (!day.visited[i]) undoneIdx.add(i);
    }

    // Auto-visite tout arrêt à proximité immédiate, peu importe l'ordre.
    if (app.lastPos != null) {
      for (final i in undoneIdx) {
        if (app.distanceTo(stops[i]) < 20) {
          WidgetsBinding.instance.addPostFrameCallback((_) => app.autoVisit(i));
        }
      }
    }

    // L'arrêt "suivant" affiché suit l'ordre de la tournée (comme un vrai
    // GPS qui te guide le long du tracé enregistré), pas le plus proche
    // à vol d'oiseau.
    final nextIdx = undoneIdx.isEmpty ? null : undoneIdx.first;
    final nextDist = nextIdx == null || app.lastPos == null
        ? double.infinity
        : app.distanceAlongTrackTo(stops[nextIdx]);

    final doneCount = day.visited.where((v) => v).length;
    final pct = stops.isEmpty ? 0.0 : doneCount / stops.length;

    return Column(
      children: [
        _StreetHeader(street: app.currentStreet, turnInstruction: app.nextTurnInstruction, colors: colors),
        const SizedBox(height: 10),
        _MapBox(colors: colors, nextStopIndex: nextIdx, navigate: true),
        if (nextIdx != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: colors.paperRaised,
              border: Border.all(color: colors.live),
              borderRadius: BorderRadius.circular(kRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROCHAIN ARRÊT',
                          style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: colors.inkSoft)),
                      const SizedBox(height: 2),
                      Text(
                        stopDisplayLabel(stops[nextIdx], nextIdx) +
                            (stops[nextIdx].note.isNotEmpty ? ' — ${stops[nextIdx].note}' : ''),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Text(
                  nextDist < 1000 ? '${nextDist.round()} m' : '${(nextDist / 1000).toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.live),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: colors.line,
            color: colors.done,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ARRÊTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: colors.inkSoft)),
            _CountPill(text: '$doneCount/${stops.length}', colors: colors),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(stops.length, (i) {
          final s = stops[i];
          final d = app.lastPos != null ? app.distanceTo(s) : null;
          return _RowCard(
            colors: colors,
            done: day.visited[i],
            highlighted: i == nextIdx,
            leading: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.inkSoft)),
            title: stopDisplayLabel(s, i),
            subtitle: s.note.isNotEmpty ? s.note : null,
            distanceText: d != null ? (d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km') : null,
            trailing: GestureDetector(
              onTap: () => context.read<AppState>().toggleVisited(i),
              child: _CheckBox(done: day.visited[i], colors: colors),
            ),
          );
        }),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => context.read<AppState>().resetFollow(),
          child: const Text('Recommencer le suivi (nouvelle journée)',
              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  const _Stat({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 9, letterSpacing: 1, color: colors.inkSoft)),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _CountPill({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.ink)),
    );
  }
}

class _Empty extends StatelessWidget {
  final AppColors colors;
  final String text;
  const _Empty({required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.inkSoft)),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool done;
  final AppColors colors;
  const _CheckBox({required this.done, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: done ? colors.done : Colors.transparent,
        border: Border.all(color: done ? colors.done : colors.line, width: 2),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: done ? Icon(Icons.check, size: 16, color: colors.paperRaised) : null,
    );
  }
}

class _RowCard extends StatelessWidget {
  final AppColors colors;
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? distanceText;
  final Widget? trailing;
  final bool done;
  final bool highlighted;

  const _RowCard({
    required this.colors,
    required this.leading,
    required this.title,
    this.subtitle,
    this.distanceText,
    this.trailing,
    this.done = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: done ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: colors.paperRaised,
          border: Border.all(color: highlighted ? colors.live : colors.line),
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 22, child: Padding(padding: const EdgeInsets.only(top: 4), child: leading)),
            const SizedBox(width: 11),
            if (trailing != null && trailing is _CheckBox) ...[trailing!, const SizedBox(width: 11)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: colors.done,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(subtitle!, style: TextStyle(fontSize: 12.5, color: colors.inkSoft)),
                    ),
                  if (distanceText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(distanceText!,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.live)),
                    ),
                ],
              ),
            ),
            if (trailing != null && trailing is! _CheckBox) trailing!,
          ],
        ),
      ),
    );
  }
}
