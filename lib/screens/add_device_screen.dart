import 'package:flutter/material.dart';
import '../models/device.dart';

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

  @override
  void initState() {
    super.initState();
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
        // Mevcut AddDeviceScreen yapınızı buraya taşıyın
        );
  }
}
