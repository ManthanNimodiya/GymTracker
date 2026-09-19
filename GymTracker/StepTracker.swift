import Foundation
import CoreMotion

/// Reads today's step count from the device's motion coprocessor via CoreMotion.
/// Pedometer operations are dispatched asynchronously so app launch remains instantaneous.
@Observable
final class StepTracker {
    private let pedometer = CMPedometer()
    private(set) var hasStarted = false
    private(set) var isQuerying = false

    var todaySteps: Int?
    var errorMessage: String?

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    init() {
        // Keep initialization completely lightweight to ensure zero launch delay
    }

    func start() {
        guard CMPedometer.isStepCountingAvailable() else {
            errorMessage = "Step counting isn't available on this device."
            return
        }

        guard !hasStarted else {
            refresh()
            return
        }

        hasStarted = true
        isQuerying = true
        let startOfDay = Calendar.current.startOfDay(for: .now)

        // Initial snapshot for today
        pedometer.queryPedometerData(from: startOfDay, to: .now) { [weak self] data, error in
            Task { @MainActor in
                self?.isQuerying = false
                self?.handle(data: data, error: error)
            }
        }

        // Live real-time updates
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            Task { @MainActor in
                self?.handle(data: data, error: error)
            }
        }
    }

    func refresh() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let startOfDay = Calendar.current.startOfDay(for: .now)
        pedometer.queryPedometerData(from: startOfDay, to: .now) { [weak self] data, error in
            Task { @MainActor in
                self?.handle(data: data, error: error)
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
        hasStarted = false
    }

    @MainActor
    private func handle(data: CMPedometerData?, error: Error?) {
        if let data {
            todaySteps = data.numberOfSteps.intValue
            errorMessage = nil
        } else if let error {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
