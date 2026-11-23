
import Foundation
import CoreBluetooth
import Observation

@Observable
final class BluetoothManager: NSObject {

    private var centralManager: CBCentralManager!

    var bluetoothState: CBManagerState = .unknown
    var discoveredDevices: [CBPeripheral] = []
    var isScanning = false

    var connectedDevice: CBPeripheral?
    var heartRate: Int?
    var connectionStatus = "Disconnected"

    private let heartRateServiceUUID =
        CBUUID(string: "180D")

    private let heartRateMeasurementUUID =
        CBUUID(string: "2A37")

    override init() {
        super.init()

        centralManager = CBCentralManager(
            delegate: self,
            queue: nil
        )
    }

    // MARK: - Scanning

    func startScanning() {
        guard bluetoothState == .poweredOn else {
            return
        }

        discoveredDevices.removeAll()

        centralManager.scanForPeripherals(
            withServices: nil,
            options: nil
        )

        isScanning = true
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    // MARK: - Connection

    func connect(to peripheral: CBPeripheral) {
        stopScanning()

        connectionStatus = "Connecting..."

        peripheral.delegate = self

        centralManager.connect(
            peripheral,
            options: nil
        )
    }

    func disconnect() {
        guard let connectedDevice else {
            return
        }

        centralManager.cancelPeripheralConnection(
            connectedDevice
        )
    }

    // MARK: - Heart Rate Parsing

    private func parseHeartRate(from data: Data) {
        let bytes = [UInt8](data)

        guard !bytes.isEmpty else {
            return
        }

        let flags = bytes[0]

        let isHeartRate16Bit = (flags & 0x01) != 0

        let bpm: Int

        if isHeartRate16Bit {
            guard bytes.count >= 3 else { return }

            bpm = Int(bytes[1]) |
                  (Int(bytes[2]) << 8)
        } else {
            guard bytes.count >= 2 else { return }

            bpm = Int(bytes[1])
        }

        heartRate = bpm
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        bluetoothState = central.state

        if central.state != .poweredOn {
            isScanning = false
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !discoveredDevices.contains(where: {
            $0.identifier == peripheral.identifier
        }) else {
            return
        }

        discoveredDevices.append(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectedDevice = peripheral
        connectionStatus = "Connected"

        peripheral.delegate = self

        peripheral.discoverServices([
            heartRateServiceUUID
        ])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectionStatus = "Connection failed"
        connectedDevice = nil
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectedDevice = nil
        heartRate = nil
        connectionStatus = "Disconnected"
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard error == nil,
              let services = peripheral.services else {
            print("Service discovery error:", error ?? "Unknown error" as Any)
            return
        }

        for service in services {
            if service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics(
                    [heartRateMeasurementUUID],
                    for: service
                )
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristics = service.characteristics else {
            print("Characteristic discovery error:", error ?? "Unknown error" as Any)
            return
        }

        for characteristic in characteristics {
            if characteristic.uuid == heartRateMeasurementUUID {
                peripheral.setNotifyValue(
                    true,
                    for: characteristic
                )
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == heartRateMeasurementUUID,
              let data = characteristic.value else {
            return
        }

        parseHeartRate(from: data)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            print("Notification error:", error)
            return
        }

        print(
            "Heart rate notifications enabled:",
            characteristic.isNotifying
        )
    }
}
