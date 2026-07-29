import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/osm_route_map.dart';

class GpsNavigationScreen extends StatelessWidget {
  const GpsNavigationScreen({super.key});

  IconData _getTurnIcon(String? direction) {
    if (direction == null) return Icons.navigation_outlined;
    switch (direction) {
      case 'droite':
        return Icons.turn_right_rounded;
      case 'gauche':
        return Icons.turn_left_rounded;
      case 'demi-tour':
        return Icons.u_turn_left_rounded;
      case 'tout droit':
      default:
        return Icons.straight_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final colors = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final route = app.data.route;

    // Get current turn guidance details
    final guidance = app.nextTurnGuidance;
    final hasTurnAction = guidance != null && guidance.direction != 'tout droit';

    final distText = guidance != null
        ? (guidance.distance < 1000
            ? '${guidance.distance.round()} m'
            : '${(guidance.distance / 1000).toStringAsFixed(1)} km')
        : '';

    // Next street or description
    String nextStreet = 'Continuer sur l\'itinéraire';
    if (guidance != null) {
      if (guidance.direction == 'demi-tour') {
        nextStreet = 'Faire demi-tour dès que possible';
      } else if (hasTurnAction) {
        nextStreet = app.nextStreetName != null
            ? 'sur ${app.nextStreetName}'
            : 'sur la rue suivante';
      }
    }

    // Determine current undone stop to pass to the map
    final undoneIdx = <int>[];
    final day = app.ensureDay(app.currentDay);
    for (var i = 0; i < route.stops.length; i++) {
      if (!day.visited[i]) undoneIdx.add(i);
    }
    final nextIdx = undoneIdx.isEmpty ? null : undoneIdx.first;

    return Scaffold(
      body: Stack(
        children: [
          // 1. FULLSCREEN MAP
          Positioned.fill(
            child: OsmRouteMap(
              track: route.points,
              stops: route.stops,
              visited: day.visited,
              live: app.lastPos,
              heading: app.lastHeading,
              startPoint: route.startPoint,
              endPoint: route.endPoint,
              uTurnZone: route.uTurnZone,
              colors: colors,
              nextStopIndex: nextIdx,
              navigate: true, // triggers auto-follow camera and orientation-up
            ),
          ),

          // 2. TOP BANNER (NAVIGATION INSTRUCTION)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                bottom: 20,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF003DA5), // Bleu La Poste
                  borderRadius: BorderRadius.circular(kRadius + 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Turn direction icon on the left
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _getTurnIcon(guidance?.direction),
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Distance and next street name on the right
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasTurnAction) ...[
                            Text(
                              distText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            const SizedBox(height: 2),
                          ] else ...[
                            const Text(
                              'Tout droit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                          Text(
                            nextStreet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. BOTTOM PANEL (CURRENT STREET & QUIT BUTTON)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black45],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 14,
                right: 14,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.paper,
                  borderRadius: BorderRadius.circular(kRadius + 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Speaker status / toggle
                    IconButton(
                      icon: Icon(
                        app.voiceGuidanceEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: colors.inkSoft,
                        size: 24,
                      ),
                      onPressed: () {
                        app.voiceGuidanceEnabled = !app.voiceGuidanceEnabled;
                      },
                    ),
                    const SizedBox(width: 8),
                    // Current street display
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'VOUS ÊTES SUR',
                            style: TextStyle(
                              color: colors.inkSoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            app.currentStreet ?? 'Localisation en cours…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Quit GPS Mode button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626), // Rouge vif
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'Quitter',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
