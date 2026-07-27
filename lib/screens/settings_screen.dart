import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionLabel('TOURNÉE', colors),
          const SizedBox(height: 8),
          _TourneeNameCard(colors: colors),
          const SizedBox(height: 24),
          _SectionLabel('ARRÊTS', colors),
          const SizedBox(height: 8),
          const _ReorderStopsCard(),
          const SizedBox(height: 24),
          _SectionLabel('CHECKLIST PAR DÉFAUT', colors),
          const SizedBox(height: 8),
          const _ChecklistTemplateCard(),
          const SizedBox(height: 24),
          _SectionLabel('SAUVEGARDE', colors),
          const SizedBox(height: 8),
          const _BackupCard(),
          const SizedBox(height: 24),
          _SectionLabel('DONNÉES', colors),
          const SizedBox(height: 8),
          _ResetCard(colors: colors),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: colors.inkSoft));
  }
}

class _TourneeNameCard extends StatelessWidget {
  final AppColors colors;
  const _TourneeNameCard({required this.colors});

  Future<void> _rename(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer la tournée'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (name != null && context.mounted) context.read<AppState>().renameTournee(name);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(app.data.tourneeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text('Nom affiché en haut de l\'application', style: TextStyle(fontSize: 12, color: colors.inkSoft)),
        trailing: Icon(Icons.edit_outlined, size: 20, color: colors.live),
        onTap: () => _rename(context, app.data.tourneeName),
      ),
    );
  }
}

class _ReorderStopsCard extends StatelessWidget {
  const _ReorderStopsCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final app = context.watch<AppState>();
    final stops = app.data.route.stops;

    if (stops.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: Text(
          "Aucun arrêt enregistré pour l'instant.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.inkSoft),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stops.length,
        onReorder: (oldIndex, newIndex) => context.read<AppState>().reorderStop(oldIndex, newIndex),
        itemBuilder: (context, i) {
          final s = stops[i];
          return Padding(
            key: ValueKey('stop_$i${s.label}${s.lat}${s.lng}'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.inkSoft)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                      if (s.note.isNotEmpty)
                        Text(s.note, style: TextStyle(fontSize: 12.5, color: colors.inkSoft)),
                    ],
                  ),
                ),
                Icon(Icons.drag_handle, color: colors.inkSoft),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChecklistTemplateCard extends StatefulWidget {
  const _ChecklistTemplateCard();

  @override
  State<_ChecklistTemplateCard> createState() => _ChecklistTemplateCardState();
}

class _ChecklistTemplateCardState extends State<_ChecklistTemplateCard> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _rename(BuildContext context, int index, String current) async {
    final controller = TextEditingController(text: current);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le point de contrôle'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (label != null && context.mounted) context.read<AppState>().renameTemplateChecklistItem(index, label);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final app = context.watch<AppState>();
    final items = app.data.checklistTemplate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.paperRaised,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text('Aucun point de contrôle par défaut.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.inkSoft)),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) =>
                      context.read<AppState>().reorderTemplateChecklistItem(oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final label = items[i];
                    return ListTile(
                      key: ValueKey('tpl_$i$label'),
                      dense: true,
                      title: Text(label, style: const TextStyle(fontSize: 14)),
                      onTap: () => _rename(context, i, label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: colors.inkSoft),
                            onPressed: () => context.read<AppState>().removeTemplateChecklistItem(i),
                          ),
                          Icon(Icons.drag_handle, color: colors.inkSoft),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addController,
                decoration: const InputDecoration(hintText: 'Ajouter un point de contrôle par défaut'),
                onSubmitted: (v) {
                  context.read<AppState>().addTemplateChecklistItem(v);
                  _addController.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                context.read<AppState>().addTemplateChecklistItem(_addController.text);
                _addController.clear();
              },
              child: const Text('+'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackupCard extends StatefulWidget {
  const _BackupCard();

  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  bool _busy = false;

  Future<void> _export(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      final content = app.exportTournee();
      final safeName = app.data.tourneeName.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$safeName.tournee');
      await file.writeAsString(content);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Export de ${app.data.tourneeName}'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['tournee'],
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null) return;
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer cette tournée ?'),
        content: const Text(
          'Toutes les données actuelles (tracé, arrêts, checklists, notes) seront remplacées par celles du fichier importé. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importer')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      final String content;
      if (picked.path != null) {
        content = await File(picked.path!).readAsString();
      } else if (picked.bytes != null) {
        content = utf8.decode(picked.bytes!);
      } else {
        throw const FormatException('Impossible de lire le fichier sélectionné.');
      }
      if (!context.mounted) return;
      await context.read<AppState>().importTournee(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournée importée avec succès.')));
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Exporte ta tournée dans un fichier .tournee pour la sauvegarder ou la transférer sur un autre appareil.",
          style: TextStyle(fontSize: 12, color: colors.inkSoft),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _export(context),
          icon: const Icon(Icons.ios_share_outlined, size: 18),
          label: const Text('Exporter ma tournée'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _import(context),
          icon: const Icon(Icons.file_open_outlined, size: 18),
          label: const Text('Importer une tournée'),
        ),
      ],
    );
  }
}

class _ResetCard extends StatelessWidget {
  final AppColors colors;
  const _ResetCard({required this.colors});

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser toutes les données ?'),
        content: const Text(
          'Le tracé enregistré, les arrêts, les checklists et les notes seront définitivement supprimés. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tout réinitialiser'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await context.read<AppState>().resetAll();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmReset(context),
        icon: Icon(Icons.delete_forever_outlined, size: 18, color: colors.danger),
        label: Text('Réinitialiser toutes les données', style: TextStyle(color: colors.danger)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.danger),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
