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
    _disconnect();
    super.dispose();
  }

  void _connect(BluetoothDevice device) async {
    if (isConnected) {
      await _disconnect();
    }

    setState(() {
      isConnecting = true;
      server = device;
    });

    try {
      // 1. Ensure Bluetooth is enabled
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }

      // 2. Cancel discovery before pairing/connecting.
      // Many SPP modules reject connections while the phone is scanning.
      debugPrint('Canceling discovery...');
      await FlutterBluetoothSerial.instance.cancelDiscovery();

      // 3. Ensure the device is bonded before attempting SPP connection.
      // Connecting to an unpaired device often fails with "read failed".
      final bondState = await FlutterBluetoothSerial.instance
          .getBondStateForAddress(device.address);
      if (bondState != BluetoothBondState.bonded) {
        debugPrint('Bonding with ${device.address}...');
        final bonded = await FlutterBluetoothSerial.instance
            .bondDeviceAtAddress(device.address);
        if (bonded != true) {
          throw Exception('Pairing failed or was canceled');
        }
      }

      // 4. Give the Bluetooth stack a moment to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));

      debugPrint('Connecting to ${device.address}...');

      // 5. Attempt connection with a timeout
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address)
          .timeout(const Duration(seconds: 15));
      
      setState(() {
        connection = conn;
        isConnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        debugPrint('Disconnected by remote device');
        setState(() {
          connection = null;
        });
      });

      // Save for next time
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_address', device.address);
      await prefs.setString('last_device_name', device.name ?? '');
      
      debugPrint('Connected to ${device.name}');
    } catch (exception) {
      setState(() {
        isConnecting = false;
        connection = null;
      });
      debugPrint('Cannot connect, exception occurred: $exception');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $exception'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _connect(device),
            ),
          ),
        );
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    debugPrint('Data received: ${utf8.decode(data)}');
  }

  Future<void> _disconnect() async {
    if (connection != null) {
      await connection!.close(); // Use close() for cleaner shutdown
      setState(() {
        connection = null;
      });
    }
  }

  void _sendMessage(int signal) async {
    if (isConnected) {
      try {
        // Many HC-05 Arduino codes expect a newline to process a command
        connection!.output.add(Uint8List.fromList(utf8.encode("$signal\n")));
        await connection!.output.allSent;
      } catch (e) {
        debugPrint("Error sending message: $e");
        _disconnect();
      }
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
