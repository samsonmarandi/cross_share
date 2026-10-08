import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/device_model.dart';

class RadarDeviceView extends StatefulWidget {
  final List<DeviceModel> devices;
  final ValueChanged<DeviceModel> onDeviceSelected;

  const RadarDeviceView({
    super.key,
    required this.devices,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final radius = size / 2 - 40;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Radar Background Rings
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _RadarPainter(
                    animationValue: _controller.value,
                    maxRadius: radius,
                  ),
                );
              },
            ),

            // Center Self Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.cell_tower, color: Colors.white, size: 30),
            ),

            // Positioned Nearby Discovered Devices
            if (widget.devices.isEmpty)
              Positioned(
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Searching for nearby devices on LAN...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            ...List.generate(widget.devices.length, (index) {
              final device = widget.devices[index];
              // Position devices in a circular layout
              final angle = (2 * pi / widget.devices.length) * index - (pi / 2);
              final dist = radius * 0.7;
              final x = center.dx + dist * cos(angle) - 35;
              final y = center.dy + dist * sin(angle) - 45;

              return Positioned(
                left: x,
                top: y,
                child: GestureDetector(
                  onTap: () => widget.onDeviceSelected(device),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getDeviceIcon(device.deviceType),
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          device.alias,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'macos':
      case 'windows':
      case 'linux':
      case 'desktop':
        return Icons.laptop;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }
}

class _RadarPainter extends CustomPainter {
  final double animationValue;
  final double maxRadius;

  _RadarPainter({required this.animationValue, required this.maxRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw static concentric circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), paint);
    }

    // Draw pulsating expanding circle
    final pulseRadius = maxRadius * animationValue;
    final pulsePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3 * (1 - animationValue))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, pulseRadius, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
