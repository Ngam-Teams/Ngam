import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sila aktifkan servis lokasi (GPS).')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Keizinan lokasi ditolak.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keizinan lokasi ditolak secara kekal. Sila tukar di tetapan peranti.')),
          );
        }
        return;
      }

      // Try to get last known position first (fast, doesn't hang emulators)
      Position? pos = await Geolocator.getLastKnownPosition();

      // If no last known position, try to get current position with low accuracy
      if (pos == null) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          throw 'Location timeout';
        });
      }
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapatkan lokasi semasa. Sila set lokasi anda di emulator.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
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
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ngam.app',
                errorTileCallback: (tile, error, stackTrace) {},
                keepBuffer: 5,
                panBuffer: 3,
                maxNativeZoom: 19,
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 40,
                      height: 40,
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedPinLocation02,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Control untuk Map (Belah Kanan)
          Positioned(
            right: 12,
            bottom: 24,
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
