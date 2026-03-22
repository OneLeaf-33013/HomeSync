import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothScanView extends StatefulWidget {
  const BluetoothScanView({super.key});

  @override
  State<BluetoothScanView> createState() => _BluetoothScanViewState();
}

class _BluetoothScanViewState extends State<BluetoothScanView> {
  List<BluetoothDevice> devices = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled != true) {
      await FlutterBluetoothSerial.instance.requestEnable();
      final enabledAfterRequest =
          await FlutterBluetoothSerial.instance.isEnabled;
      if (enabledAfterRequest != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Bluetooth first.')),
          );
        }
        return;
      }
    }

    // Request permissions for Bluetooth Connect (paired devices list)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.bluetoothConnect] == PermissionStatus.granted) {
      await _loadBondedDevices();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth Connect permission is required.'),
          ),
        );
      }
    }
  }

  Future<void> _loadBondedDevices() async {
    setState(() {
      devices.clear();
      isLoading = true;
    });

    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      debugPrint('Bonded devices count: ${bonded.length}');
      for (final d in bonded) {
        debugPrint(
          'Bonded: name=${d.name ?? "unknown"} addr=${d.address} '
          'type=${d.type} bond=${d.bondState} connected=${d.isConnected}',
        );
      }

      bonded.sort((a, b) {
        final aName = (a.name ?? '').toLowerCase();
        final bName = (b.name ?? '').toLowerCase();
        if (aName != bName) return aName.compareTo(bName);
        return a.address.compareTo(b.address);
      });

      if (mounted) {
        setState(() {
          devices = bonded;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load paired devices: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paired Bluetooth Devices'),
        actions: [
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: _checkPermissionsAndLoad,
            )
          ,
          IconButton(
            icon: const Icon(Icons.settings_bluetooth),
            onPressed: () => FlutterBluetoothSerial.instance.openSettings(),
          ),
        ],
      ),
      body: devices.isEmpty
          ? const Center(
              child: Text('No paired devices. Pair in Bluetooth settings and refresh.'),
            )
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final typeLabel = device.type.toString().replaceFirst('BluetoothDeviceType.', '');
                final bondLabel = device.bondState.toString().replaceFirst('BluetoothBondState.', '');
                return ListTile(
                  title: Text(device.name ?? "Unknown Device"),
                  subtitle: Text('${device.address} • $typeLabel • $bondLabel'),
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
