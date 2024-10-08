import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import 'add_device_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Device> devices = [];
  Device? selectedDevice;
  bool isSending = false;
  late DeviceService deviceService;

  @override
  void initState() {
    super.initState();
    deviceService = DeviceService();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    devices = await deviceService.loadDevices();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // Mevcut HomeScreen yapınızı buraya taşıyın
        );
  }
}
