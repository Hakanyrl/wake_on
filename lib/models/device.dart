class Device {
  String name;
  String mac;
  String ip;
  String ping;
  String port;
  int colorValue;
  bool isSelected;

  Device({
    required this.name,
    required this.mac,
    required this.ip,
    required this.ping,
    required this.port,
    required this.colorValue,
    this.isSelected = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mac': mac,
      'ip': ip,
      'ping': ping,
      'port': port,
      'color': colorValue,
      'isSelected': isSelected,
    };
  }

  static Device fromJson(Map<String, dynamic> json) {
    return Device(
      name: json['name'],
      mac: json['mac'],
      ip: json['ip'],
      ping: json['ping'],
      port: json['port'],
      colorValue: json['color'],
      isSelected: json['isSelected'] ?? false,
    );
  }
}
