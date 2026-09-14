import Foundation
import CoreMotion

/// Reads today's step count from the device's motion coprocessor via CoreMotion.
///
/// This (not HealthKit) is the practical choice here: HealthKit's entitlement requires a paid
/// Apple Developer account, while CMPedometer only needs the standard Motion & Fitness runtime
/// permission, which works with a free/personal signing team. It only reports real data on a
/// physical device — the Simulator has no motion hardware.
@Observable
final class StepTracker {
    private let pedometer = CMPedometer()
    private(set) var hasStarted = false

    var todaySteps: Int?
    var errorMessage: String?

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        guard CMPedometer.isStepCountingAvailable() else {
            errorMessage = "Step counting isn't available on this device."
            return
        }

        let startOfDay = Calendar.current.startOfDay(for: .now)

        pedometer.queryPedometerData(from: startOfDay, to: .now) { [weak self] data, error in
            Task { @MainActor in
                self?.handle(data: data, error: error)
            }
        }

        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            Task { @MainActor in
                self?.handle(data: data, error: error)
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
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
