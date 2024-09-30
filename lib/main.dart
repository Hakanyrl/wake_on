import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const WakeOnLanApp());
}

class WakeOnLanApp extends StatelessWidget {
  const WakeOnLanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wake on LAN',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class Device {
  final String name;
  final String mac;
  final String ip;
  final String ping;
  final String port;
  final Color color;
  bool isSelected;

  Device({
    required this.name,
    required this.mac,
    required this.ip,
    required this.ping,
    required this.port,
    required this.color,
    this.isSelected = false,
  });

  // Device nesnesini JSON formatına dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mac': mac,
      'ip': ip,
      'ping': ping,
      'port': port,
      'color': color.value, // Rengi int olarak saklayacağız
      'isSelected': isSelected
    };
  }

  // JSON'dan Device nesnesi oluşturma
  static Device fromJson(Map<String, dynamic> json) {
    return Device(
      name: json['name'],
      mac: json['mac'],
      ip: json['ip'],
      ping: json['ping'],
      port: json['port'],
      color: Color(json['color']),
      isSelected: json['isSelected'] ?? false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Device> devices = [];
  final List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  // Cihazları yükleme
  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? devicesString = prefs.getString('devices');
    if (devicesString != null) {
      final List<dynamic> decodedDevices = jsonDecode(devicesString);
      setState(() {
        devices = decodedDevices
            .map((deviceJson) => Device.fromJson(deviceJson))
            .toList();
      });
    }
  }

  // Cihazları kaydetme
  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String devicesString =
        jsonEncode(devices.map((device) => device.toJson()).toList());
    await prefs.setString('devices', devicesString);
  }

  // Seçilen cihazları silme
  Future<void> _deleteSelectedDevices() async {
    setState(() {
      devices.removeWhere((device) => device.isSelected);
    });
    _saveDevices();
  }

  // MAC adresini normalize etme (xx-xx-xx-xx-xx-xx -> xx:xx:xx:xx:xx:xx)
  String _normalizeMacAddress(String macAddress) {
    return macAddress.replaceAll('-', ':');
  }

  void _sendWakeOnLan(
      String macAddress, String broadcastAddress, int port) async {
    String normalizedMac = _normalizeMacAddress(macAddress);

    // Magic Packet oluşturma
    List<int> macBytes = _getMacBytes(normalizedMac);
    List<int> magicPacket = List.filled(6, 0xFF) +
        List.filled(16, macBytes).expand((x) => x).toList();

    // Paket içeriğini konsola yazdır (debug amaçlı)
    print("Magic Packet: $magicPacket");
    print("MAC Address: $normalizedMac");
    print("Broadcast Address: $broadcastAddress");
    print("Port: $port");

    // UDP üzerinden paket gönderme
    try {
      await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        socket.broadcastEnabled = true;

        // Paket gönderimi
        socket.send(
          Uint8List.fromList(magicPacket),
          InternetAddress(broadcastAddress),
          port, // Kullanıcının belirlediği port numarası
        );

        // Soketi kapatıyoruz
        socket.close();
        print("Wake on LAN paketi başarıyla gönderildi!");
      }).catchError((error) {
        // Paket gönderiminde hata oluştu
        print("UDP paket gönderim hatası: ${error.toString()}");
      });
    } catch (e) {
      // Genel hata yönetimi
      print("UDP paket gönderiminde bir hata oluştu: ${e.toString()}");
    }
  }

  // MAC adresini bytelara çevirme
  List<int> _getMacBytes(String macAddress) {
    return macAddress
        .split(':')
        .map((octet) => int.parse(octet, radix: 16))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake on LAN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedDevices, // Seçilen cihazları sil
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: devices.isEmpty
                ? const Center(child: Text("Henüz cihaz eklenmedi."))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Card(
                        color: device.color,
                        child: ListTile(
                          leading: Checkbox(
                            value: device.isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                device.isSelected = value ?? false;
                              });
                            },
                          ),
                          title: Text(device.name),
                          subtitle: Text(
                              "MAC: ${device.mac}, IP: ${device.ip}, Port: ${device.port}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.power),
                                onPressed: () {
                                  // Wake on LAN gönder
                                  _sendWakeOnLan(device.mac, device.ip,
                                      int.parse(device.port));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.power_off),
                                onPressed: () {
                                  // "Off" fonksiyonu burada (İsteğe göre eklenebilir)
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  // Cihazı düzenleme
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => AddDeviceScreen(
                                              device: device,
                                            )),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      devices[index] = result;
                                    });
                                    _saveDevices();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddDeviceScreen()),
                );

                if (result != null) {
                  setState(() {
                    devices.add(result);
                  });
                  _saveDevices(); // Cihaz eklendiğinde kaydet
                }
              },
              child: const Text('Ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class AddDeviceScreen extends StatefulWidget {
  final Device? device;

  const AddDeviceScreen({super.key, this.device});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController macController = TextEditingController();
  final TextEditingController ipController = TextEditingController();
  final TextEditingController pingController = TextEditingController();
  final TextEditingController portController = TextEditingController();

  final List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();

    // Eğer düzenlenmekte olan bir cihaz varsa mevcut değerleri yükle
    if (widget.device != null) {
      nameController.text = widget.device!.name;
      macController.text = widget.device!.mac;
      ipController.text = widget.device!.ip;
      pingController.text = widget.device!.ping;
      portController.text = widget.device!.port;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'Cihaz Ekle' : 'Cihazı Düzenle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Cihaz İsmi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: macController,
              decoration: const InputDecoration(
                labelText: 'MAC Adresi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Adresi (Broadcast IP)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pingController,
              decoration: const InputDecoration(
                labelText: 'Ping Adresi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Yeni cihaz oluşturma veya mevcut cihazı güncelleme
                if (nameController.text.isNotEmpty &&
                    macController.text.isNotEmpty &&
                    ipController.text.isNotEmpty &&
                    pingController.text.isNotEmpty &&
                    portController.text.isNotEmpty) {
                  final randomColor = widget.device?.color ??
                      colors[Random().nextInt(colors.length)];
                  final newDevice = Device(
                    name: nameController.text,
                    mac: macController.text,
                    ip: ipController.text,
                    ping: pingController.text,
                    port: portController.text,
                    color: randomColor,
                  );

                  Navigator.pop(context, newDevice);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
