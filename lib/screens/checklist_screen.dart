import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final app = context.watch<AppState>();
    final day = app.ensureDay(app.currentDay);
    final doneCount = day.checklist.where((i) => i.done).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('AVANT DE PARTIR',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: colors.inkSoft)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: colors.paperRaised,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$doneCount/${day.checklist.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.ink)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(day.checklist.length, (i) {
          final item = day.checklist[i];
          return Opacity(
            opacity: item.done ? 0.5 : 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: colors.paperRaised,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Row(
                children: [
                  // Vert "fait" plutôt que le bleu de sélection Halo : ici la case
                  // représente une tâche accomplie (succès), pas un simple champ de
                  // formulaire sélectionné — sémantique différente, couleur différente.
                  GestureDetector(
                    onTap: () => context.read<AppState>().toggleChecklist(i),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: item.done ? colors.done : Colors.transparent,
                        border: Border.all(color: item.done ? colors.done : colors.line, width: 2),
                        borderRadius: BorderRadius.circular(kRadius),
                      ),
                      child: item.done ? Icon(Icons.check, size: 15, color: colors.paperRaised) : null,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        decoration: item.done ? TextDecoration.lineThrough : null,
                        decorationColor: colors.done,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: colors.inkSoft),
                    onPressed: () => context.read<AppState>().deleteChecklistItem(i),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Ajouter un point de contrôle'),
                onSubmitted: (v) {
                  context.read<AppState>().addChecklistItem(v);
                  _controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                context.read<AppState>().addChecklistItem(_controller.text);
                _controller.clear();
              },
              child: const Text('+'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.read<AppState>().resetChecklist(),
            child: const Text('Décocher toute la checklist',
                style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
          ),
        ),
      ],
    );
  }
}
