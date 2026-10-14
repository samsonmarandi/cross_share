import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/device_model.dart';

class RadarDeviceView extends StatefulWidget {
  final List<DeviceModel> devices;
  final List<String> pairedDeviceIds;
  final ValueChanged<DeviceModel> onDeviceSelected;

  const RadarDeviceView({
    super.key,
    required this.devices,
    this.pairedDeviceIds = const [],
    required this.onDeviceSelected,
  });

  @override
  State<RadarDeviceView> createState() => _RadarDeviceViewState();
}

class _RadarDeviceViewState extends State<RadarDeviceView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final radius = max(size / 2 - 50, 80.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Animated Radar Rings Background
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _RadarPainter(
                    animationValue: _controller.value,
                    maxRadius: radius,
                    primaryColor: primaryColor,
                  ),
                );
              },
            ),

            // Center Self Device Beacon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_tethering_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),

            // Searching Status Indicator (Positioned safely above bottom tray)
            if (widget.devices.isEmpty)
              Positioned(
                bottom: 85,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Searching for nearby devices on LAN...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Discovered Nearby Devices
            ...List.generate(widget.devices.length, (index) {
              final device = widget.devices[index];
              final isPaired = widget.pairedDeviceIds.contains(device.id);
              final angle = (2 * pi / widget.devices.length) * index - (pi / 2);
              final dist = radius * 0.72;
              final x = center.dx + dist * cos(angle) - 32;
              final y = center.dy + dist * sin(angle) - 40;

              return Positioned(
                left: x,
                top: y,
                child: InkWell(
                  onTap: () => widget.onDeviceSelected(device),
                  borderRadius: BorderRadius.circular(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: isPaired
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPaired ? Colors.green : primaryColor,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getDeviceIcon(device.deviceType),
                              color: isPaired ? Colors.green.shade700 : primaryColor,
                              size: 28,
                            ),
                          ),
                          if (isPaired)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.link_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPaired) ...[
                              const Icon(Icons.check_circle, color: Colors.green, size: 10),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              device.alias,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'macos':
      case 'windows':
      case 'linux':
      case 'desktop':
        return Icons.laptop_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}

class _RadarPainter extends CustomPainter {
  final double animationValue;
  final double maxRadius;
  final Color primaryColor;

  _RadarPainter({
    required this.animationValue,
    required this.maxRadius,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw static concentric radar rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), paint);
    }

    // Draw pulsating radar wave
    final pulseRadius = maxRadius * animationValue;
    final pulsePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25 * (1 - animationValue))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, pulseRadius, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
