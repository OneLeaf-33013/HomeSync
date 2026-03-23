package com.zcode.HomeSync;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;

import androidx.core.content.ContextCompat;

import java.io.IOException;
import java.security.InvalidParameterException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

class SerialSocket extends BluetoothGattCallback {

    private static final UUID CLIENT_CHARACTERISTIC_CONFIG_UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private final BroadcastReceiver disconnectBroadcastReceiver;

    private final Context context;
    private final BluetoothDevice device;
    private SerialListener listener;
    private BluetoothGatt gatt;
    private BluetoothGattCharacteristic writeCharacteristic;
    private BluetoothGattCharacteristic notifyCharacteristic;
    private boolean connected;

    SerialSocket(Context context, BluetoothDevice device) {
        if (context instanceof Activity) {
            throw new InvalidParameterException("expected non UI context");
        }
        this.context = context;
        this.device = device;
        disconnectBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (listener != null) {
                    listener.onSerialIoError(new IOException("background disconnect"));
                }
                disconnect();
            }
        };
    }

    String getName() {
        return device.getName() != null ? device.getName() : device.getAddress();
    }

    void connect(SerialListener listener) throws IOException {
        this.listener = listener;
        ContextCompat.registerReceiver(
                context,
                disconnectBroadcastReceiver,
                new IntentFilter(Constants.INTENT_ACTION_DISCONNECT),
                ContextCompat.RECEIVER_NOT_EXPORTED
        );

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            gatt = device.connectGatt(context, false, this, BluetoothDevice.TRANSPORT_LE);
        } else {
            gatt = device.connectGatt(context, false, this);
        }
        if (gatt == null) {
            throw new IOException("gatt connection failed to start");
        }
    }

    void disconnect() {
        listener = null;
        connected = false;
        writeCharacteristic = null;
        notifyCharacteristic = null;
        if (gatt != null) {
            try {
                gatt.disconnect();
            } catch (Exception ignored) {
            }
            try {
                gatt.close();
            } catch (Exception ignored) {
            }
            gatt = null;
        }
        try {
            context.unregisterReceiver(disconnectBroadcastReceiver);
        } catch (Exception ignored) {
        }
    }

    void write(byte[] data) throws IOException {
        if (!connected || gatt == null || writeCharacteristic == null) {
            throw new IOException("not connected");
        }
        boolean success;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            success = gatt.writeCharacteristic(writeCharacteristic, data, resolveWriteType(writeCharacteristic))
                    == BluetoothGatt.GATT_SUCCESS;
        } else {
            writeCharacteristic.setWriteType(resolveWriteType(writeCharacteristic));
            writeCharacteristic.setValue(data);
            success = gatt.writeCharacteristic(writeCharacteristic);
        }
        if (!success) {
            throw new IOException("failed to write characteristic");
        }
    }

    @Override
    public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
        if (status != BluetoothGatt.GATT_SUCCESS) {
            notifyConnectError(new IOException("gatt error " + status));
            safeClose(gatt);
            return;
        }
        if (newState == BluetoothGatt.STATE_CONNECTED) {
            if (!gatt.discoverServices()) {
                notifyConnectError(new IOException("service discovery failed to start"));
                safeClose(gatt);
            }
        } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
            connected = false;
            if (listener != null) {
                listener.onSerialIoError(new IOException("disconnected"));
            }
            safeClose(gatt);
        }
    }

    @Override
    public void onServicesDiscovered(BluetoothGatt gatt, int status) {
        if (status != BluetoothGatt.GATT_SUCCESS) {
            notifyConnectError(new IOException("service discovery failed: " + status));
            safeClose(gatt);
            return;
        }

        writeCharacteristic = findWriteCharacteristic(gatt.getServices());
        notifyCharacteristic = findNotifyCharacteristic(gatt.getServices(), writeCharacteristic);

        if (writeCharacteristic == null) {
            notifyConnectError(new IOException("no writable GATT characteristic found"));
            safeClose(gatt);
            return;
        }

        if (notifyCharacteristic != null) {
            if (!enableNotifications(gatt, notifyCharacteristic)) {
                notifyConnectError(new IOException("failed to enable notifications"));
                safeClose(gatt);
                return;
            }
            return;
        }

        connected = true;
        if (listener != null) {
            listener.onSerialConnect();
        }
    }

    @Override
    public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
        if (status != BluetoothGatt.GATT_SUCCESS) {
            notifyConnectError(new IOException("descriptor write failed: " + status));
            safeClose(gatt);
            return;
        }
        connected = true;
        if (listener != null) {
            listener.onSerialConnect();
        }
    }

    @Override
    public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
        byte[] value = characteristic.getValue();
        if (listener != null && value != null) {
            listener.onSerialRead(value);
        }
    }

    @Override
    public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, byte[] value) {
        if (listener != null && value != null) {
            listener.onSerialRead(value);
        }
    }

    @Override
    public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
        if (status == BluetoothGatt.GATT_SUCCESS) {
            byte[] value = characteristic.getValue();
            if (listener != null && value != null) {
                listener.onSerialRead(value);
            }
        }
    }

    @SuppressLint("MissingPermission")
    private boolean enableNotifications(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
        if (!gatt.setCharacteristicNotification(characteristic, true)) {
            return false;
        }
        BluetoothGattDescriptor descriptor = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID);
        if (descriptor == null) {
            connected = true;
            if (listener != null) {
                listener.onSerialConnect();
            }
            return true;
        }

        byte[] value = supportsIndicate(characteristic)
                ? BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                : BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return gatt.writeDescriptor(descriptor, value) == BluetoothGatt.GATT_SUCCESS;
        }

        descriptor.setValue(value);
        return gatt.writeDescriptor(descriptor);
    }

    private int resolveWriteType(BluetoothGattCharacteristic characteristic) {
        int properties = characteristic.getProperties();
        if ((properties & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0) {
            return BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;
        }
        return BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT;
    }

    private BluetoothGattCharacteristic findWriteCharacteristic(List<BluetoothGattService> services) {
        List<BluetoothGattCharacteristic> fallback = new ArrayList<>();
        for (BluetoothGattService service : services) {
            for (BluetoothGattCharacteristic characteristic : service.getCharacteristics()) {
                int properties = characteristic.getProperties();
                boolean canWrite = (properties & BluetoothGattCharacteristic.PROPERTY_WRITE) != 0
                        || (properties & BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0;
                if (!canWrite) {
                    continue;
                }
                if (looksLikeDataCharacteristic(characteristic)) {
                    return characteristic;
                }
                fallback.add(characteristic);
            }
        }
        return fallback.isEmpty() ? null : fallback.get(0);
    }

    private BluetoothGattCharacteristic findNotifyCharacteristic(List<BluetoothGattService> services,
                                                                 BluetoothGattCharacteristic preferredServiceCharacteristic) {
        List<BluetoothGattCharacteristic> fallback = new ArrayList<>();
        UUID preferredServiceUuid = preferredServiceCharacteristic != null
                ? preferredServiceCharacteristic.getService().getUuid()
                : null;

        for (BluetoothGattService service : services) {
            for (BluetoothGattCharacteristic characteristic : service.getCharacteristics()) {
                if (!supportsNotify(characteristic) && !supportsIndicate(characteristic)) {
                    continue;
                }
                if (preferredServiceUuid != null && preferredServiceUuid.equals(service.getUuid())
                        && looksLikeDataCharacteristic(characteristic)) {
                    return characteristic;
                }
                if (looksLikeDataCharacteristic(characteristic)) {
                    fallback.add(0, characteristic);
                } else {
                    fallback.add(characteristic);
                }
            }
        }
        return fallback.isEmpty() ? null : fallback.get(0);
    }

    private boolean supportsNotify(BluetoothGattCharacteristic characteristic) {
        return (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0;
    }

    private boolean supportsIndicate(BluetoothGattCharacteristic characteristic) {
        return (characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0;
    }

    private boolean looksLikeDataCharacteristic(BluetoothGattCharacteristic characteristic) {
        String uuid = characteristic.getUuid().toString().toLowerCase(Locale.US);
        return uuid.contains("ffe1")
                || uuid.contains("ffe2")
                || uuid.contains("6e400002")
                || uuid.contains("6e400003")
                || uuid.contains("2a56")
                || uuid.contains("2a58");
    }

    private void notifyConnectError(IOException e) {
        connected = false;
        if (listener != null) {
            listener.onSerialConnectError(e);
        }
    }

    private void safeClose(BluetoothGatt activeGatt) {
        if (gatt == activeGatt) {
            try {
                activeGatt.close();
            } catch (Exception ignored) {
            }
            gatt = null;
        }
        try {
            context.unregisterReceiver(disconnectBroadcastReceiver);
        } catch (Exception ignored) {
        }
        connected = false;
        writeCharacteristic = null;
        notifyCharacteristic = null;
    }
}
