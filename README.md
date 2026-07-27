# Ma Tournée

Application Flutter compagnon de tournée pour facteur, pensée pour fonctionner **hors connexion** au quotidien (une poignée de fonctions comme la carte, l'OCR colis ou le nom de rue nécessitent un accès réseau ponctuel, avec repli silencieux si absent).

## Fonctionnalités

- **Enregistrement de tournée** : trace le parcours GPS en marchant, avec détection automatique des arrêts (immobilité ≥10s) et point de tracé forcé au moins toutes les 30s.
- **Suivi façon GPS** : carte OpenStreetMap avec caméra qui suit la position et pivote selon le cap, guidage tour-par-tour ("Dans 15 m, tourne à droite") déduit du tracé enregistré, nom de la rue affiché en direct (reverse-geocoding).
- **Scan de colis (OCR)** : photographie les étiquettes dans le désordre, l'adresse est repérée automatiquement (reconnaissance de texte sur l'appareil) puis les arrêts sont insérés dans l'ordre réel de la tournée.
- **Checklist et notes** journalières, avec modèle de checklist par défaut personnalisable.
- **Suivi en arrière-plan** (service Android en foreground, mode background iOS).
- **Import / export** de la tournée au format `.tournee` (fichier encodé, transférable entre appareils).
- **Charte visuelle** basée sur le design system "Halo" de La Poste (couleurs, typographies Montserrat/Roboto).

## Démarrer

```bash
flutter pub get
flutter run
```

Après tout ajout de permission (GPS, caméra, notifications) dans le code, une **réinstallation complète** est nécessaire — un hot reload/restart ne suffit pas :

```bash
flutter run   # pas de hot reload pour les changements de permissions
```

## Structure

```
lib/
  main.dart                    Point d'entrée, navigation, thème
  app_state.dart                État global (GPS, tracé, arrêts, checklist, notes...)
  models.dart                   Modèles de données (AppData, Stop, RoutePoint...)
  storage.dart                  Persistance locale (shared_preferences)
  theme.dart                    Couleurs et typographie (DA La Poste)
  package_scan.dart             OCR + géocodage des colis scannés
  tournee_file.dart             Encodage/décodage du format .tournee
  screens/                      Écrans (tournée, checklist, notes, scan colis, paramètres)
  widgets/osm_route_map.dart    Carte OpenStreetMap (flutter_map)
```

## Format `.tournee`

Le JSON de la tournée est brouillé par XOR avec la clé `TOURNEE` (réversible) puis encodé en base64, accompagné d'une empreinte SHA-256 du contenu d'origine pour détecter un fichier corrompu ou invalide à l'import. Voir `lib/tournee_file.dart`.

## Limites connues

- La carte et le géocodage (adresse ↔ position) nécessitent une connexion réseau ; les zones déjà consultées restent en cache pour un usage hors ligne ultérieur.
- Le guidage tour-par-tour se base uniquement sur le tracé que tu as toi-même enregistré, pas sur un calcul d'itinéraire routier.
- Sur iOS, le suivi en arrière-plan prolongé nécessite d'autoriser la localisation "Toujours" manuellement dans les réglages du téléphone.
