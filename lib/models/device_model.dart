class DeviceModel {
  final String id;
  final String alias;
  final String ip;
  final int port;
  final String deviceType; // 'android', 'ios', 'windows', 'macos', 'linux', 'web'
  final DateTime lastSeen;
  final bool isWeb;

  DeviceModel({
    required this.id,
    required this.alias,
    required this.ip,
    required this.port,
    required this.deviceType,
    required this.lastSeen,
    this.isWeb = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alias': alias,
      'ip': ip,
      'port': port,
      'deviceType': deviceType,
      'lastSeen': lastSeen.toIso8601String(),
      'isWeb': isWeb,
    };
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String? ?? 'unknown',
      alias: json['alias'] as String? ?? 'Unknown Device',
      ip: json['ip'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 53317,
      deviceType: json['deviceType'] as String? ?? 'unknown',
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      isWeb: json['isWeb'] as bool? ?? false,
    );
  }

  DeviceModel copyWith({
    String? id,
    String? alias,
    String? ip,
    int? port,
    String? deviceType,
    DateTime? lastSeen,
    bool? isWeb,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      lastSeen: lastSeen ?? this.lastSeen,
      isWeb: isWeb ?? this.isWeb,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
