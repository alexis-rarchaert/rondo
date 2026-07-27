import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../package_scan.dart';
import '../theme.dart';

class PackageScanScreen extends StatefulWidget {
  const PackageScanScreen({super.key});

  @override
  State<PackageScanScreen> createState() => _PackageScanScreenState();
}

class _PackageScanScreenState extends State<PackageScanScreen> {
  final _scanner = PackageScanner();
  final _picker = ImagePicker();
  final _packages = <ScannedPackage>[];
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) return;

    final pkg = ScannedPackage(imagePath: photo.path);
    setState(() => _packages.add(pkg));

    try {
      final text = await _scanner.extractText(photo.path);
      pkg.addressGuess = _scanner.guessAddress(text);
    } catch (_) {
      pkg.error = "Lecture impossible, entre l'adresse à la main";
    }
    if (!mounted) return;
    setState(() {});
    await _geocode(pkg);
  }

  // Un léger délai entre chaque appel Nominatim pour rester sous leur
  // limite d'1 requête/seconde quand plusieurs colis sont traités à la suite.
  Future<void> _geocode(ScannedPackage pkg) async {
    setState(() => pkg.processing = true);
    final point = await _scanner.geocode(pkg.addressGuess);
    if (!mounted) return;
    setState(() {
      pkg.point = point;
      pkg.processing = false;
      if (point == null) pkg.error ??= 'Adresse non localisée — corrige-la et relance';
    });
    await Future.delayed(const Duration(milliseconds: 1100));
  }

  Future<void> _confirmAll() async {
    setState(() => _busy = true);
    final stops = <Stop>[];
    for (final pkg in _packages) {
      if (pkg.point == null) continue;
      stops.add(Stop(lat: pkg.point!.lat, lng: pkg.point!.lng, label: pkg.addressGuess));
    }
    if (stops.isNotEmpty && mounted) {
      context.read<AppState>().addScannedStops(stops);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final geocodedCount = _packages.where((p) => p.geocoded).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner des colis')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              "Prends une photo de l'étiquette de chaque colis, dans n'importe quel ordre. "
              "L'adresse est repérée automatiquement et les arrêts seront ajoutés dans l'ordre réel de ta tournée.",
              style: TextStyle(fontSize: 12.5, color: colors.inkSoft),
            ),
          ),
          Expanded(
            child: _packages.isEmpty
                ? Center(
                    child: Text('Aucun colis scanné pour l\'instant', style: TextStyle(color: colors.inkSoft)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _packages.length,
                    itemBuilder: (context, i) => _PackageCard(
                      key: ValueKey(_packages[i]),
                      colors: colors,
                      pkg: _packages[i],
                      onRetry: () => _geocode(_packages[i]),
                      onAddressChanged: (v) => _packages[i].addressGuess = v,
                      onRemove: () => setState(() => _packages.removeAt(i)),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Prendre une photo'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: !_busy && geocodedCount > 0 ? _confirmAll : null,
                    child: Text(
                      geocodedCount > 0 ? 'Ajouter $geocodedCount arrêt${geocodedCount > 1 ? 's' : ''}' : 'Ajouter les arrêts',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatefulWidget {
  final AppColors colors;
  final ScannedPackage pkg;
  final VoidCallback onRetry;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onRemove;

  const _PackageCard({
    super.key,
    required this.colors,
    required this.pkg,
    required this.onRetry,
    required this.onAddressChanged,
    required this.onRemove,
  });

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  late final TextEditingController _controller;
  // Dernière valeur connue de pkg.addressGuess qu'on a nous-même poussée
  // dans le contrôleur — sert à détecter un nouveau résultat OCR externe
  // sans écraser une saisie manuelle en cours.
  late String _syncedGuess;

  @override
  void initState() {
    super.initState();
    _syncedGuess = widget.pkg.addressGuess;
    _controller = TextEditingController(text: _syncedGuess);
  }

  @override
  void didUpdateWidget(covariant _PackageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pkg.addressGuess != _syncedGuess && _controller.text == _syncedGuess) {
      _controller.text = widget.pkg.addressGuess;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
    _syncedGuess = widget.pkg.addressGuess;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final pkg = widget.pkg;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border.all(color: pkg.geocoded ? colors.done : colors.line),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kRadius - 2),
            child: Image.file(File(pkg.imagePath), width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10)),
                  onChanged: widget.onAddressChanged,
                  onSubmitted: (_) => widget.onRetry(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (pkg.processing) ...[
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 6),
                      Text('Analyse en cours…', style: TextStyle(fontSize: 11.5, color: colors.inkSoft)),
                    ] else if (pkg.geocoded) ...[
                      Icon(Icons.check_circle_outline, size: 15, color: colors.done),
                      const SizedBox(width: 4),
                      Text('Adresse localisée', style: TextStyle(fontSize: 11.5, color: colors.done)),
                    ] else ...[
                      Icon(Icons.error_outline, size: 15, color: colors.danger),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(pkg.error ?? 'Adresse non localisée', style: TextStyle(fontSize: 11.5, color: colors.danger)),
                      ),
                      TextButton(onPressed: widget.onRetry, child: const Text('Réessayer', style: TextStyle(fontSize: 11.5))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: colors.inkSoft),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
