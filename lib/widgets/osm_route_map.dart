import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart' as state;
import '../models.dart';
import '../theme.dart';

class OsmRouteMap extends StatefulWidget {
  final List<RoutePoint> track;
  final List<Stop> stops;
  final List<bool> visited;
  final state.LatLng? live;
  final double? heading;
  final int? nextStopIndex;
  final AppColors colors;
  final Stop? startPoint;
  final Stop? endPoint;
  final Stop? uTurnZone;

  // Mode navigation "vrai GPS" : la caméra suit la position en direct et
  // pivote selon le cap (heading-up), comme sur un GPS de voiture/piéton.
  final bool navigate;

  const OsmRouteMap({
    super.key,
    required this.track,
    required this.stops,
    required this.visited,
    required this.live,
    this.heading,
    required this.nextStopIndex,
    required this.colors,
    this.navigate = false,
    this.startPoint,
    this.endPoint,
    this.uTurnZone,
  });

  @override
  State<OsmRouteMap> createState() => _OsmRouteMapState();
}

class _OsmRouteMapState extends State<OsmRouteMap> {
  final _mapController = MapController();
  bool _fitted = false;
  late bool _autoFollow = widget.navigate;

  LatLng? _ll(state.LatLng? p) => p == null ? null : LatLng(p.lat, p.lng);

  @override
  void didUpdateWidget(covariant OsmRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.navigate || !_autoFollow || widget.live == null) return;
    final moved = oldWidget.live == null ||
        oldWidget.live!.lat != widget.live!.lat ||
        oldWidget.live!.lng != widget.live!.lng ||
        oldWidget.heading != widget.heading;
    if (moved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followCamera());
    }
  }

  void _followCamera() {
    if (!mounted) return;
    final live = _ll(widget.live);
    if (live == null) return;
    final zoom = _mapController.camera.zoom;
    _mapController.moveAndRotate(live, zoom < 16 ? 17.5 : zoom, -(widget.heading ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.track.map((p) => LatLng(p.lat, p.lng)).toList();
    final live = _ll(widget.live);

    final bounds = <LatLng>[
      ...points,
      ...widget.stops.map((s) => LatLng(s.lat, s.lng)),
      if (widget.startPoint != null) LatLng(widget.startPoint!.lat, widget.startPoint!.lng),
      if (widget.endPoint != null) LatLng(widget.endPoint!.lat, widget.endPoint!.lng),
      if (widget.uTurnZone != null) LatLng(widget.uTurnZone!.lat, widget.uTurnZone!.lng),
      ?live,
    ];

    if (!_fitted && bounds.isNotEmpty) {
      _fitted = true;
      if (widget.navigate && live != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.move(live, 17.5);
        });
      } else {
        final target = bounds;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (target.length == 1) {
            _mapController.move(target.first, 17);
          } else {
            _mapController.fitCamera(
              CameraFit.coordinates(
                coordinates: target,
                padding: const EdgeInsets.all(32),
                maxZoom: 18,
              ),
            );
          }
        });
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: bounds.isNotEmpty ? bounds.first : const LatLng(46.6, 2.2),
              initialZoom: bounds.isNotEmpty ? 16 : 5,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _autoFollow) {
                  setState(() => _autoFollow = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.matournee.app',
              ),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      color: widget.colors.inkSoft.withValues(alpha: 0.6),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              if (widget.uTurnZone != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(widget.uTurnZone!.lat, widget.uTurnZone!.lng),
                      radius: widget.uTurnZone!.radius ?? 30.0,
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.25),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < widget.stops.length; i++)
                    Marker(
                      point: LatLng(widget.stops[i].lat, widget.stops[i].lng),
                      width: 26,
                      height: 26,
                      rotate: true,
                      child: _StopPin(
                        index: i + 1,
                        done: i < widget.visited.length && widget.visited[i],
                        isNext: i == widget.nextStopIndex,
                        colors: widget.colors,
                      ),
                    ),
                  if (widget.startPoint != null)
                    Marker(
                      point: LatLng(widget.startPoint!.lat, widget.startPoint!.lng),
                      width: 30,
                      height: 30,
                      rotate: true,
                      child: _StartPin(colors: widget.colors),
                    ),
                  if (widget.endPoint != null)
                    Marker(
                      point: LatLng(widget.endPoint!.lat, widget.endPoint!.lng),
                      width: 30,
                      height: 30,
                      rotate: true,
                      child: _EndPin(colors: widget.colors),
                    ),
                  if (widget.uTurnZone != null)
                    Marker(
                      point: LatLng(widget.uTurnZone!.lat, widget.uTurnZone!.lng),
                      width: 30,
                      height: 30,
                      rotate: true,
                      child: _UTurnPin(colors: widget.colors),
                    ),
                  if (live != null)
                    Marker(
                      point: live,
                      width: 20,
                      height: 20,
                      rotate: true,
                      child: _LiveDot(colors: widget.colors),
                    ),
                ],
              ),
              SimpleAttributionWidget(
                source: const Text('OpenStreetMap contributors', style: TextStyle(fontSize: 10)),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
          if (widget.navigate)
            Positioned(
              right: 8,
              bottom: 56,
              child: FloatingActionButton.small(
                heroTag: 'follow_toggle',
                backgroundColor: _autoFollow ? widget.colors.accent : widget.colors.paperRaised,
                foregroundColor: _autoFollow ? widget.colors.accentInk : widget.colors.live,
                elevation: 1,
                onPressed: live == null
                    ? null
                    : () {
                        setState(() => _autoFollow = true);
                        _followCamera();
                      },
                child: const Icon(Icons.navigation_outlined, size: 20),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map',
              backgroundColor: widget.colors.paperRaised,
              foregroundColor: widget.colors.live,
              elevation: 1,
              onPressed: live == null
                  ? null
                  : () => _mapController.move(live, _mapController.camera.zoom),
              child: const Icon(Icons.my_location_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopPin extends StatelessWidget {
  final int index;
  final bool done;
  final bool isNext;
  final AppColors colors;

  const _StopPin({required this.index, required this.done, required this.isNext, required this.colors});

  @override
  Widget build(BuildContext context) {
    final bg = done ? colors.done : (isNext ? colors.accent : colors.paperRaised);
    final fg = done || isNext ? colors.accentInk : colors.ink;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: colors.line, width: isNext ? 2 : 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: Text('$index', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _LiveDot extends StatelessWidget {
  final AppColors colors;
  const _LiveDot({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.live,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: colors.live.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 2)],
      ),
    );
  }
}

class _StartPin extends StatelessWidget {
  final AppColors colors;
  const _StartPin({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: const Text('D', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _EndPin extends StatelessWidget {
  final AppColors colors;
  const _EndPin({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: const Text('F', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _UTurnPin extends StatelessWidget {
  final AppColors colors;
  const _UTurnPin({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.undo, color: Colors.white, size: 16),
    );
  }
}
