import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'ngam_maps_dialog.dart';
import 'glass_toast.dart';

class MapPicker extends StatefulWidget {
  final LatLng initialCenter;
  final ValueChanged<LatLng> onLocationSelected;

  const MapPicker({
    super.key,
    required this.initialCenter,
    required this.onLocationSelected,
  });

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  double _rotation = 0.0;
  bool _isLoadingLocation = false;


  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchCurrentLocation() async {
    if (mounted) {
      setState(() => _isLoadingLocation = true);
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showGlassToast(
            context,
            'Sila aktifkan servis lokasi (GPS).',
            isError: true,
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            showGlassToast(
              context,
              'Keizinan lokasi ditolak.',
              isError: true,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showGlassToast(
            context,
            'Keizinan lokasi ditolak secara kekal. Sila tukar di tetapan peranti.',
            isError: true,
          );
        }
        return;
      }

      // Try to get last known position first (fast, doesn't hang emulators)
      Position? pos = await Geolocator.getLastKnownPosition();

      // If no last known position, try to get current position with low accuracy
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw 'Location timeout';
      });
      
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        _mapController.move(latLng, 15.0);
        setState(() {
          _selectedLocation = latLng;
        });
        widget.onLocationSelected(latLng);
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(
          context,
          'Gagal mendapatkan lokasi semasa. Sila set lokasi anda di peranti.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _searchPhoton(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final results = <Map<String, dynamic>>[];

    // 1. Enjin Utama: Nominatim (Rasmi OpenStreetMap Malaysia)
    try {
      final client = HttpClient();
      final nomUri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&addressdetails=1&limit=5&countrycodes=my',
      );
      final request = await client.getUrl(nomUri);
      request.headers.set('User-Agent', 'NgamApp/1.0 (contact@ngam.my)');
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List? ?? [];
        for (final item in list) {
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          final name = item['name']?.toString() ?? '';
          final displayName = item['display_name']?.toString() ?? '';
          final addr = item['address'] as Map<String, dynamic>? ?? {};
          final subtitle = [
            addr['road'] ?? addr['suburb'],
            addr['city'] ?? addr['town'] ?? addr['county'],
            addr['state'],
          ].where((p) => p != null && p.toString().isNotEmpty).join(', ');

          if (lat != 0.0 && lon != 0.0) {
            results.add({
              'title': name.isNotEmpty ? name : (subtitle.isNotEmpty ? subtitle : displayName),
              'subtitle': subtitle.isNotEmpty ? subtitle : displayName,
              'lat': lat,
              'lng': lon,
            });
          }
        }
      }
    } catch (_) {}

    // 2. Sandaran (Fallback): Photon Komoot
    if (results.isEmpty) {
      try {
        final client = HttpClient();
        final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&limit=5&lat=${widget.initialCenter.latitude}&lon=${widget.initialCenter.longitude}',
        );
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final features = data['features'] as List? ?? [];
          for (final f in features) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final geom = f['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List? ?? [];
            if (coords.length >= 2) {
              final lon = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              final name = props['name'] ?? props['street'] ?? '';
              final parts = [
                props['street'],
                props['city'] ?? props['county'],
                props['state'],
              ].where((p) => p != null && p.toString().isNotEmpty && p != name).join(', ');

              results.add({
                'title': name.isNotEmpty ? name : (parts.isNotEmpty ? parts : 'Lokasi'),
                'subtitle': parts,
                'lat': lat,
                'lng': lon,
              });
            }
          }
        }
      } catch (_) {}
    }

    return results;
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String searchQuery = '';
        List<Map<String, dynamic>> results = [];
        bool isSearching = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cari Alamat atau Kawasan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Taip nama tempat, jalan, atau poskod...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onChanged: (val) async {
                      searchQuery = val;
                      if (val.trim().length >= 3) {
                        setSheetState(() => isSearching = true);
                        final res = await _searchPhoton(val);
                        if (searchQuery == val) {
                          setSheetState(() {
                            results = res;
                            isSearching = false;
                          });
                        }
                      } else {
                        setSheetState(() => results = []);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              searchQuery.length < 3
                                  ? 'Taip sekurang-kurangnya 3 huruf untuk mula mencari.'
                                  : (isSearching ? 'Sedang mencari...' : 'Tiada lokasi dijumpai.'),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.blue),
                                title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: (item['subtitle'] as String).isNotEmpty
                                    ? Text(item['subtitle'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                                    : null,
                                onTap: () {
                                  final lat = item['lat'] as double;
                                  final lng = item['lng'] as double;
                                  final pos = LatLng(lat, lng);
                                  _mapController.move(pos, 16.0);
                                  setState(() {
                                    _selectedLocation = pos;
                                  });
                                  widget.onLocationSelected(pos);
                                  Navigator.pop(sheetContext);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 13.0,
              onMapReady: _fetchCurrentLocation,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
                widget.onLocationSelected(point);
              },

              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (position, hasGesture) {
                if (position.rotation != _rotation) {
                  setState(() {
                    _rotation = position.rotation;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=cb1_470b_1_5dec1f354e103fb7efca8d68',
                userAgentPackageName: 'com.ngam.app',
                errorTileCallback: (tile, error, stackTrace) {},
                keepBuffer: 5,
                panBuffer: 3,
                maxNativeZoom: 19,
                tileBuilder: (context, tileWidget, tile) {
                  if (!isDark) return tileWidget;
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                       0.574, -1.430, -0.144, 0.0, 265.0,
                      -0.426, -0.430, -0.144, 0.0, 265.0,
                      -0.426, -1.430,  0.856, 0.0, 270.0,
                       0.0,    0.0,    0.0,   1.0,   0.0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              if (_selectedLocation != null) ...[
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _selectedLocation!,
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                      borderColor: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                      radius: 80,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 44,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 44,
                            color: Color(0xFFE53935),
                          ),
                          Positioned(
                            top: 12,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          
          // NgamMaps Attribution Badge (Belah Kiri Bawah - Gaya Grab)
          Positioned(
            left: 10,
            bottom: 10,
            child: NgamMapsAttributionBadge(isDark: isDark),
          ),

          // Control untuk Map (Belah Kanan)
          Positioned(
            right: 12,
            bottom: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Butang pusing Utara balik
                if (_rotation != 0.0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: FloatingActionButton.small(
                      heroTag: 'compass_btn',
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      onPressed: () {
                        _mapController.rotate(0);
                      },
                      child: Transform.rotate(
                        angle: -_rotation * (3.1415926535897932 / 180),
                        child: const Icon(Icons.navigation),
                      ),
                    ),
                  ),
                // Butang cari alamat / kawasan
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: FloatingActionButton.small(
                    heroTag: 'search_address_btn',
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    tooltip: 'Cari Alamat',
                    onPressed: _openSearchSheet,
                    child: const Icon(Icons.search),
                  ),
                ),
                // Butang cari aku kat mana
                FloatingActionButton.small(
                  heroTag: 'gps_btn',
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: _fetchCurrentLocation,
                  child: _isLoadingLocation 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
