import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'bluetooth_scan_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothConnection? connection;
  BluetoothDevice? server;
  bool isConnecting = false;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isLight1On = false;
  bool isLight2On = false;
  bool isFanOn = false;

  @override
  void initState() {
    super.initState();
    _loadAndConnect();
  }

  Future<void> _loadAndConnect() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? address = prefs.getString('last_device_address');
    String? name = prefs.getString('last_device_name');
    if (address != null) {
      _connect(BluetoothDevice(address: address, name: name));
    }
  }

  @override
  void dispose() {
    if (isConnected) {
      connection?.dispose();
      connection = null;
    }
    super.dispose();
  }

  void _connect(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
      server = device;
    });

    try {
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnecting = false;
      });
      
      // Save for next time
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_address', device.address);
      await prefs.setString('last_device_name', device.name ?? '');
      
      debugPrint('Connected to ${device.name}');
    } catch (exception) {
      setState(() {
        isConnecting = false;
      });
      debugPrint('Cannot connect, exception occurred: $exception');
    }
  }

  void _disconnect() {
    if (isConnected) {
      connection?.dispose();
      setState(() {
        connection = null;
      });
    }
  }

  void _sendMessage(int signal) async {
    if (isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode(signal.toString() + "\r\n")));
      await connection!.output.allSent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? '${server?.name}' : 'HomeSync (Disconnected)'),
        backgroundColor: isConnected ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (isConnecting)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white)))
          else
            IconButton(
              icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
              onPressed: () async {
                final BluetoothDevice? selectedDevice = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const BluetoothScanView()),
                );
                if (selectedDevice != null) {
                  _connect(selectedDevice);
                }
              },
            ),
            if (isConnected)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _disconnect,
              )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleButton(
                  icon: Icons.lightbulb,
                  isOn: isLight1On,
                  onTap: () {
                    setState(() => isLight1On = !isLight1On);
                    _sendMessage(0);
                  },
                ),
                const SizedBox(height: 30),
                _buildCircleButton(
                  icon: Icons.lightbulb,
                  isOn: isLight2On,
                  onTap: () {
                    setState(() => isLight2On = !isLight2On);
                    _sendMessage(1);
                  },
                ),
                const SizedBox(height: 30),
                _buildCircleButton(
                  icon: Icons.mode_fan_off,
                  activeIcon: Icons.air,
                  isOn: isFanOn,
                  onTap: () {
                    setState(() => isFanOn = !isFanOn);
                    _sendMessage(2);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    IconData? activeIcon,
    required bool isOn,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? Colors.yellow : Colors.black,
          border: Border.all(color: Colors.grey, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          isOn && activeIcon != null ? activeIcon : icon,
          size: 80,
          color: isOn ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
