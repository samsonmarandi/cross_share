class PairedDeviceModel {
  final String id;
  final String alias;
  final String deviceType;
  final String authToken;
  final DateTime pairedAt;

  PairedDeviceModel({
    required this.id,
    required this.alias,
    required this.deviceType,
    required this.authToken,
    required this.pairedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alias': alias,
      'deviceType': deviceType,
      'authToken': authToken,
      'pairedAt': pairedAt.toIso8601String(),
    };
  }

  factory PairedDeviceModel.fromJson(Map<String, dynamic> json) {
    return PairedDeviceModel(
      id: json['id'] as String,
      alias: json['alias'] as String,
      deviceType: json['deviceType'] as String? ?? 'unknown',
      authToken: json['authToken'] as String,
      pairedAt: DateTime.parse(json['pairedAt'] as String),
    );
  }
}
