import Foundation

enum ImpactSeverity: String, Sendable {
    case major      // 4+ detectors, amplitude > 0.05g
    case medium     // 3+ detectors, amplitude > 0.02g
    case micro      // Peak detector, amplitude > 0.005g
    case vibration  // STA/LTA or CUSUM, amplitude > 0.003g
}

struct ImpactEvent: Sendable {
    let severity: ImpactSeverity
    let amplitude: Double
    let timestamp: TimeInterval
    let detectorCount: Int
}
