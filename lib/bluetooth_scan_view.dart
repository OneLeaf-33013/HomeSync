import 'package:flutter/material.dart';

class BluetoothScanView extends StatelessWidget {
  const BluetoothScanView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scan & Connect'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Available Bluetooth Devices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 5, // Placeholder for device count
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text('Device #${index + 1}'),
                  subtitle: const Text('Tap to connect'),
                  onTap: () {
                    // No connection logic here
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
