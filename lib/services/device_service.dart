import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/device.dart';

class DeviceService {
  Future<List<Device>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? devicesString = prefs.getString('devices');
    if (devicesString != null) {
      final List<dynamic> decodedDevices = jsonDecode(devicesString);
      return decodedDevices
          .map((deviceJson) => Device.fromJson(deviceJson))
          .toList();
    }
    return [];
  }

  Future<void> saveDevices(List<Device> devices, Device? selectedDevice) async {
    final prefs = await SharedPreferences.getInstance();
    final String devicesString =
        jsonEncode(devices.map((device) => device.toJson()).toList());
    await prefs.setString('devices', devicesString);
    if (selectedDevice != null) {
      final String selectedDeviceString = jsonEncode(selectedDevice.toJson());
      await prefs.setString('selectedDevice', selectedDeviceString);
    }
  }

  Future<void> sendWakeOnLan(
      String macAddress, String broadcastAddress, int port) async {
    String normalizedMac = _normalizeMacAddress(macAddress);
    List<int> macBytes = _getMacBytes(normalizedMac);
    List<int> magicPacket = List.filled(6, 0xFF) +
        List.filled(16, macBytes).expand((x) => x).toList();

    try {
      await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        socket.broadcastEnabled = true;
        socket.send(Uint8List.fromList(magicPacket),
            InternetAddress(broadcastAddress), port);
        socket.close();
      });
    } catch (e) {
      print("UDP paket gönderim hatası: ${e.toString()}");
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

  Future<void> shutdownComputer(String ping) async {
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

  Future<void> restartComputer(String ping) async {
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
}
