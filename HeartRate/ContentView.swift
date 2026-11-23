
import SwiftUI
import CoreBluetooth

struct ContentView: View {

    @State private var bluetoothManager = BluetoothManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // MARK: - Connection Status

                VStack(spacing: 8) {
                    Text(bluetoothManager.connectionStatus)
                        .font(.headline)

                    if let device = bluetoothManager.connectedDevice {
                        Text(device.name ?? "Unknown device")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Heart Rate

                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)

                    Text(
                        bluetoothManager.heartRate.map {
                            "\($0)"
                        } ?? "--"
                    )
                    .font(.system(size: 64, weight: .bold))

                    Text("BPM")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)

                // MARK: - Scanning

                Button {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                    }
                } label: {
                    Text(
                        bluetoothManager.isScanning
                            ? "Stop scanning"
                            : "Search devices"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // MARK: - Discovered Devices

                List {
                    Section("Available devices") {
                        ForEach(
                            bluetoothManager.discoveredDevices,
                            id: \.identifier
                        ) { device in

                            Button {
                                bluetoothManager.connect(to: device)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(
                                            device.name ?? "Unknown device"
                                        )

                                        Text(
                                            device.identifier.uuidString
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.right.circle")
                                }
                            }
                            .disabled(
                                bluetoothManager.connectedDevice != nil
                            )
                        }
                    }
                }

                // MARK: - Disconnect

                if bluetoothManager.connectedDevice != nil {
                    Button("Disconnect") {
                        bluetoothManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .navigationTitle("Heart Rate Monitor")
        }
    }
}
