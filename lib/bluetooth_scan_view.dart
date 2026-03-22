import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class BluetoothScanView extends StatefulWidget {
  const BluetoothScanView({super.key});

  @override
  State<BluetoothScanView> createState() => _BluetoothScanViewState();
}

class _BluetoothScanViewState extends State<BluetoothScanView> {
  List<BluetoothDiscoveryResult> results = [];
  bool isDiscovering = false;
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStart();
  }

  Future<void> _checkPermissionsAndStart() async {
    // Request permissions for Bluetooth Scan, Connect and Location
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted) {
      _startDiscovery();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth Scan and Connect permissions are required.'),
          ),
        );
      }
    }
  }

  void _startDiscovery() {
    if (isDiscovering) return;

    setState(() {
      results.clear();
      isDiscovering = true;
    });

    _discoveryStreamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        final existingIndex = results.indexWhere(
            (element) => element.device.address == r.device.address);
        if (existingIndex >= 0) {
          results[existingIndex] = r;
        } else {
          results.add(r);
        }
      });
    });

    _discoveryStreamSubscription?.onDone(() {
      setState(() {
        isDiscovering = false;
      });
    });
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Classic Scan'),
        actions: [
          if (isDiscovering)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: _checkPermissionsAndStart,
            )
        ],
      ),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          BluetoothDiscoveryResult result = results[index];
          final device = result.device;
          return ListTile(
            title: Text(device.name ?? "Unknown Device"),
            subtitle: Text(device.address),
            trailing: ElevatedButton(
              child: const Text('Connect'),
              onPressed: () {
                // Return the selected device to the previous screen
                Navigator.of(context).pop(device);
              },
            ),
          );
        },
      ),
    );
  }
}
