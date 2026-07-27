import 'package:flutter/material.dart';

// Couleurs et typographie alignées sur le design system "Halo" de La Poste
// (tokens `.lib-laposte` extraits de leur CSS public de documentation :
// https://documentation-toolbox.laposte.fr). Le thème sombre n'existe pas
// dans leur charte (Halo est pensé pour un usage clair) : les teintes ont
// été adaptées ici pour rester lisibles sur fond sombre, en conservant le
// jaune de marque tel quel.

// --halo-radius-small (rayon commun aux boutons et cartes dans .lib-button
// et .lib-card-list).
const double kRadius = 8;

class AppColors {
  final Color paper;
  final Color paperRaised;
  final Color ink;
  final Color inkSoft;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color done;
  final Color danger;
  final Color live;
  final Color link;
  final Color fieldBorder;

  const AppColors({
    required this.paper,
    required this.paperRaised,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.done,
    required this.danger,
    required this.live,
    required this.link,
    required this.fieldBorder,
  });

  // --halo-neutral-*, --halo-brand-*, --halo-action-primary-*,
  // --halo-status-content-success/error, --halo-global-content-link
  // de .lib-laposte.
  static const light = AppColors(
    paper: Color(0xFFF6F6F6),
    paperRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF353535),
    inkSoft: Color(0xFF636363),
    line: Color(0xFFE2E2E2),
    accent: Color(0xFFFFCB05),
    accentInk: Color(0xFF353535),
    done: Color(0xFF007F00),
    danger: Color(0xFFC61111),
    live: Color(0xFF003DA5),
    link: Color(0xFF0058E1),
    fieldBorder: Color(0xFFC6C6C6),
  );

  static const dark = AppColors(
    paper: Color(0xFF171717),
    paperRaised: Color(0xFF212121),
    ink: Color(0xFFF1F1F1),
    inkSoft: Color(0xFFB0B0B0),
    line: Color(0xFF3C3C3C),
    accent: Color(0xFFFFCB05),
    accentInk: Color(0xFF272400),
    done: Color(0xFF66BB6A),
    danger: Color(0xFFE57373),
    live: Color(0xFF6C9BFF),
    link: Color(0xFF7EB6FF),
    fieldBorder: Color(0xFF636363),
  );
}

ThemeData buildTheme(AppColors c, Brightness brightness) {
  const montserrat = 'Montserrat';
  const roboto = 'Roboto';

  final textTheme = TextTheme(
    displayLarge: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    displayMedium: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    displaySmall: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    headlineLarge: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    headlineMedium: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    headlineSmall: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    titleLarge: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
    titleMedium: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w600),
    titleSmall: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w600),
    bodyLarge: const TextStyle(fontFamily: roboto, fontWeight: FontWeight.w400),
    bodyMedium: const TextStyle(fontFamily: roboto, fontWeight: FontWeight.w400),
    bodySmall: const TextStyle(fontFamily: roboto, fontWeight: FontWeight.w400),
    labelLarge: const TextStyle(fontFamily: roboto, fontWeight: FontWeight.w600),
    labelMedium: const TextStyle(fontFamily: roboto, fontWeight: FontWeight.w600),
    labelSmall: const TextStyle(fontFamily: roboto, fontWeight: FontWeight.w600),
  ).apply(bodyColor: c.ink, displayColor: c.ink);

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: c.paper,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.done,
      onSecondary: c.accentInk,
      error: c.danger,
      onError: c.accentInk,
      surface: c.paperRaised,
      onSurface: c.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.paper,
      foregroundColor: c.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.paperRaised,
      indicatorColor: c.accent.withValues(alpha: 0.25),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: roboto,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: selected ? c.ink : c.inkSoft,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? c.ink : c.inkSoft);
      }),
    ),
    cardColor: c.paperRaised,
    dividerColor: c.line,
    fontFamily: roboto,
    textTheme: textTheme,
    // .lib-button.lib-variant-filled : fond jaune de marque, texte encre,
    // rayon 8px, libellé Montserrat 700 (police commune à tous les boutons
    // Halo, quel que soit le variant).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentInk,
        disabledBackgroundColor: c.line,
        disabledForegroundColor: c.inkSoft,
        textStyle: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    // .lib-button.lib-variant-outlined : transparent, bordure et texte encre.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.ink),
        disabledForegroundColor: c.inkSoft,
        textStyle: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ).copyWith(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return BorderSide(color: c.inkSoft);
          return BorderSide(color: c.ink);
        }),
      ),
    ),
    // .lib-button.lib-variant-text : pas de bordure, couleur de lien
    // (--halo-global-content-link), utilisé pour les actions secondaires
    // type "annuler" ou "réinitialiser".
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.link,
        disabledForegroundColor: c.inkSoft,
        textStyle: const TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      ),
    ),
    // .lib-spinner : indicateur en couleur de lien, piste en gris désactivé,
    // trait de 4px sur un rond de 48px.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.link,
      circularTrackColor: c.line,
      strokeWidth: 4,
    ),
    // .lib-form-field .lib-field : bordure grise (edition-border-default),
    // rayon 8px, focus/erreur en couleur de lien/danger, fond plein.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.paperRaised,
      hintStyle: TextStyle(color: c.inkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c.link, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c.danger, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c.line),
      ),
    ),
    // .lib-popin-panel : fond plein, rayon 8px, pas d'ombre, titre
    // Montserrat 700 24px, texte Roboto 400 16px.
    dialogTheme: DialogThemeData(
      backgroundColor: c.paperRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      titleTextStyle: TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700, fontSize: 24, color: c.ink),
      contentTextStyle: TextStyle(fontFamily: roboto, fontWeight: FontWeight.w400, fontSize: 16, color: c.ink),
    ),
    // .mat-calendar-body-selected : fond bleu de marque, texte blanc
    // (--halo-selection-primary-background/content-selected) ; aujourd'hui
    // non-sélectionné : texte + contour bleu de marque. Tout est fixé
    // explicitement ci-dessous pour qu'aucune couleur ne retombe sur le
    // jaune de `colorScheme.primary` par défaut.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.paperRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      headerBackgroundColor: c.paperRaised,
      headerForegroundColor: c.ink,
      headerHeadlineStyle: TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700, fontSize: 30, color: c.ink),
      headerHelpStyle: TextStyle(fontFamily: roboto, fontWeight: FontWeight.w500, fontSize: 12, color: c.inkSoft),
      weekdayStyle: TextStyle(fontFamily: roboto, fontWeight: FontWeight.w600, color: c.inkSoft),
      dayStyle: TextStyle(fontFamily: roboto, fontWeight: FontWeight.w400, color: c.ink),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return c.ink;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.live;
        return null;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return c.live;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.live;
        return Colors.transparent;
      }),
      todayBorder: BorderSide(color: c.live),
      yearStyle: TextStyle(fontFamily: roboto, fontWeight: FontWeight.w400, color: c.ink),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return c.ink;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.live;
        return null;
      }),
      dividerColor: c.line,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: c.link,
        textStyle: TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: c.link,
        textStyle: TextStyle(fontFamily: montserrat, fontWeight: FontWeight.w700),
      ),
    ),
    // .lib-switch : piste sélectionnée en bleu de marque + curseur blanc ;
    // piste non-sélectionnée blanche avec contour encre.
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return c.line;
        if (states.contains(WidgetState.selected)) return c.live;
        return c.paperRaised;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.live;
        return c.ink;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return c.inkSoft;
        if (states.contains(WidgetState.selected)) return Colors.white;
        return c.ink;
      }),
    ),
    // Cases à cocher génériques Material (le composant "checklist" de
    // l'app est un widget maison en vert "fait", volontairement distinct :
    // voir la note dans checklist_screen.dart).
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: c.ink, width: 2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return c.line;
        if (states.contains(WidgetState.selected)) return c.live;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
  );
}
