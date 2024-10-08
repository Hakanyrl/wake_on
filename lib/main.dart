import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WakeOnLanApp());
}

class WakeOnLanApp extends StatelessWidget {
  const WakeOnLanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wake On Lan',
      theme: ThemeData(
        brightness: Brightness.dark, // Arka planı koyu yapmak için
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Device> devices = [];
  Device? selectedDevice;
  bool isSending = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool buttonPressed = false;
  PageController _pageController =
      PageController(viewportFraction: 0.6); // Daha akıcı kaydırma için
  int _currentPage = 1; // Ortadaki buton

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? devicesString = prefs.getString('devices');
    final String? selectedDeviceString = prefs.getString('selectedDevice');

    if (devicesString != null) {
      final List<dynamic> decodedDevices = jsonDecode(devicesString);
      setState(() {
        devices = decodedDevices
            .map((deviceJson) => Device.fromJson(deviceJson))
            .toList();
      });
    }

    if (selectedDeviceString != null) {
      final Map<String, dynamic> selectedDeviceJson =
          jsonDecode(selectedDeviceString);
      setState(() {
        selectedDevice = Device.fromJson(selectedDeviceJson);
      });
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String devicesString =
        jsonEncode(devices.map((device) => device.toJson()).toList());
    await prefs.setString('devices', devicesString);

    if (selectedDevice != null) {
      final String selectedDeviceString = jsonEncode(selectedDevice!.toJson());
      await prefs.setString('selectedDevice', selectedDeviceString);
    }
  }

  void _deleteDevice(Device device) {
    setState(() {
      devices.remove(device);
    });
    _saveDevices();
  }

  Future<void> _scanDevices() async {
    const int startRange = 1;
    const int endRange = 254;
    String subnet = "192.168.1.";
    List<Future<void>> futures = [];

    for (int i = startRange; i <= endRange; i++) {
      String ip = '$subnet$i';
      futures.add(_checkDevice(ip));
    }

    await Future.wait(futures);
    _saveDevices();
  }

  Future<void> _checkDevice(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:3000/info'))
          .timeout(const Duration(seconds: 1));

      if (response.statusCode == 200) {
        final deviceData = jsonDecode(response.body);
        final newDevice = Device(
          name: deviceData['name'],
          mac: deviceData['mac'],
          ip: deviceData['ip'],
          ping: deviceData['ping'],
          port: '9',
          colorValue: Colors.blue.value,
        );

        setState(() {
          devices.add(newDevice);
        });
      }
    } catch (e) {
      print('Cihaz bulunamadı: $ip');
    }
  }

  String _normalizeMacAddress(String macAddress) {
    return macAddress.replaceAll('-', ':');
  }

  List<int> _getMacBytes(String macAddress) {
    return macAddress
        .split(':')
        .map((octet) => int.parse(octet, radix: 16))
        .toList();
  }

  Future<void> _sendWakeOnLan(
      String macAddress, String broadcastAddress, int port) async {
    String normalizedMac = _normalizeMacAddress(macAddress);

    List<int> macBytes = _getMacBytes(normalizedMac);
    List<int> magicPacket = List.filled(6, 0xFF) +
        List.filled(16, macBytes).expand((x) => x).toList();

    try {
      await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        socket.broadcastEnabled = true;

        socket.send(
          Uint8List.fromList(magicPacket),
          InternetAddress(broadcastAddress),
          port,
        );

        socket.close();
      }).catchError((error) {
        print("UDP paket gönderim hatası: ${error.toString()}");
      });
    } catch (e) {
      print("UDP paket gönderiminde bir hata oluştu: ${e.toString()}");
    }

    setState(() {
      isSending = true;
      buttonPressed = true;
    });

    await _controller.forward();
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      isSending = false;
    });
    _controller.reset();
    setState(() {
      buttonPressed = false;
    });
  }

  Future<void> _shutdownComputer(String ping) async {
    try {
      final response = await http.get(Uri.parse('http://$ping:3000/shutdown'));
      if (response.statusCode == 200) {
        print("Bilgisayar kapatılıyor.");
      } else {
        print("Kapatma işlemi başarısız: ${response.statusCode}");
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _restartComputer(String ping) async {
    try {
      final response = await http.get(Uri.parse('http://$ping:3000/restart'));
      if (response.statusCode == 200) {
        print("Bilgisayar yeniden başlatılıyor.");
      } else {
        print("Yeniden başlatma işlemi başarısız: ${response.statusCode}");
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''), // Başlık boş bırakıldı
        centerTitle: false, // Başlığı ortaya hizalayabilirsiniz (isteğe bağlı)
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              child: Text('Kayıtlı Cihazlar'),
            ),
            Expanded(
              child: devices.isEmpty
                  ? const Center(child: Text("Henüz cihaz eklenmedi."))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return Container(
                          color: Color(device.colorValue).withOpacity(0.2),
                          child: ListTile(
                            title: Text(device.name),
                            subtitle: Text(device.ip),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              AddDeviceScreen(device: device)),
                                    );
                                    if (result != null) {
                                      setState(() {
                                        devices[index] = result;
                                      });
                                      _saveDevices();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    _deleteDevice(device);
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                selectedDevice = device;
                              });
                              _saveDevices();
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Uygulama Sürümü: 0.1.1',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Üst kısım: Seçili cihaz ve diğer içerikler
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  if (selectedDevice != null)
                    Column(
                      children: [
                        Text(
                          'Seçili Cihaz:',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Color(selectedDevice!.colorValue)
                                .withOpacity(0.2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                selectedDevice!.name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(selectedDevice!.colorValue),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                selectedDevice!.ip,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 100,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 3,
                      onPageChanged: (int index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        bool isActive = index == _currentPage;
                        return CircularButton(
                          icon: getIconForIndex(index),
                          isActive: isActive,
                          onPressed:
                              isActive ? () => _onButtonPressed(index) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Alt kısım: Butonlar
          Padding(
            padding:
                const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sol aşağıdaki "Cihaz Ekle" butonu
                SizedBox(
                  width: 160,
                  child: TextButton.icon(
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
                        _saveDevices();
                      }
                    },
                    icon: const Icon(Icons.add, size: 30),
                    label: const Text(
                      "Cihaz Ekle",
                      style: TextStyle(fontSize: 18),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                // Sağ aşağıdaki "Cihaz Ara" butonu
                SizedBox(
                  width: 160,
                  child: TextButton.icon(
                    onPressed: _scanDevices,
                    icon: const Icon(Icons.search_sharp, size: 30),
                    label: const Text(
                      "Cihaz Ara",
                      style: TextStyle(fontSize: 18),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.power_settings_new;
      case 1:
        return Icons.restart_alt;
      case 2:
        return Icons.power_off;
      default:
        return Icons.help;
    }
  }

  void _onButtonPressed(int index) {
    if (selectedDevice == null) {
      print("Lütfen önce bir cihaz seçin.");
      return;
    }

    switch (index) {
      case 0:
        print('Wake on LAN butonu tıklandı');
        _sendWakeOnLan(selectedDevice!.mac, selectedDevice!.ip,
            int.parse(selectedDevice!.port));

        break;
      case 1:
        print('Yeniden Başlat butonu tıklandı');
        _restartComputer(selectedDevice!.ping);
        break;
      case 2:
        print('Kapat butonu tıklandı');
        _shutdownComputer(selectedDevice!.ping);
        break;
    }
  }
}

class CircularButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;

  const CircularButton({
    super.key,
    required this.icon,
    required this.isActive,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isActive ? 80 : 70, // Seçildiğinde biraz büyütülmüş boyut
        height: isActive ? 80 : 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? const Color.fromARGB(255, 228, 3, 3)
              : Colors.grey.withOpacity(0.5),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: const Color.fromARGB(66, 202, 177, 177),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : [], // Aktif olan buton gölgeli olacak
        ),
        child: Icon(
          icon,
          size: 40, // İkonun boyutu sabit kalacak
          color: isActive ? Colors.white : Colors.grey[400],
        ),
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

  final List<int> colorValues = [
    Colors.red.value,
    Colors.blue.value,
    Colors.green.value,
    Colors.orange.value,
    Colors.purple.value,
    Colors.brown.value,
    Colors.cyan.value,
  ];

  int selectedColorValue = Colors.blue.value;

  @override
  void initState() {
    super.initState();

    if (widget.device != null) {
      nameController.text = widget.device!.name;
      macController.text = widget.device!.mac;
      ipController.text = widget.device!.ip;
      pingController.text = widget.device!.ping;
      portController.text = widget.device!.port;
      selectedColorValue = widget.device!.colorValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'Cihaz Ekle' : 'Cihazı Düzenle'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
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
                  DropdownButton<int>(
                    value: selectedColorValue,
                    items: colorValues.map((colorValue) {
                      return DropdownMenuItem<int>(
                        value: colorValue,
                        child: Container(
                          width: 100,
                          height: 20,
                          color: Color(colorValue),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? newColorValue) {
                      setState(() {
                        selectedColorValue = newColorValue!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    macController.text.isNotEmpty &&
                    ipController.text.isNotEmpty &&
                    pingController.text.isNotEmpty &&
                    portController.text.isNotEmpty) {
                  final newDevice = Device(
                    name: nameController.text,
                    mac: macController.text,
                    ip: ipController.text,
                    ping: pingController.text,
                    port: portController.text,
                    colorValue: selectedColorValue,
                  );
                  Navigator.pop(context, newDevice);
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
