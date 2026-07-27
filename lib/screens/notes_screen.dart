import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _controller = TextEditingController();
  final _timeFmt = DateFormat('HH:mm', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final app = context.watch<AppState>();
    final day = app.ensureDay(app.currentDay);
    final notes = day.notes.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('NOTES DU JOUR',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: colors.inkSoft)),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Ex : boîte n°14 en travaux, remettre au gardien...',
            contentPadding: EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              context.read<AppState>().addNote(_controller.text);
              _controller.clear();
            },
            child: const Text('Enregistrer'),
          ),
        ),
        const SizedBox(height: 22),
        Text('HISTORIQUE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: colors.inkSoft)),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(kRadius),
            ),
            child: Text("Pas encore de note aujourd'hui.",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.inkSoft)),
          )
        else
          ...notes.map((note) {
            final idx = day.notes.indexOf(note);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: colors.paperRaised,
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_timeFmt.format(DateTime.fromMillisecondsSinceEpoch(note.ts)),
                          style: TextStyle(fontSize: 11, color: colors.inkSoft)),
                      GestureDetector(
                        onTap: () => context.read<AppState>().deleteNote(idx),
                        child: Icon(Icons.close, size: 16, color: colors.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(note.text, style: const TextStyle(fontSize: 14, height: 1.35)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
