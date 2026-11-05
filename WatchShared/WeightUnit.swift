import Foundation

nonisolated enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg = "Kg", lb = "Lb"

    private static let lbPerKg = 2.20462

    /// Converts kilograms (how weights are stored) to this unit.
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg * Self.lbPerKg }

    func toKg(_ value: Double) -> Double { self == .kg ? value : value / Self.lbPerKg }

    /// Step of the − / + weight buttons.
    var step: Double { self == .kg ? 0.25 : 0.5 }

    /// [kg] shown in this unit: kilograms to 0.01 so 0.25 kg steps show exactly ("57.25"), pounds to 0.1
    /// (converted from kilograms they rarely land on a round number): "126.8".
    func weightNumber(_ kg: Double) -> String {
        self == .kg ? Weights.number(kg) : Weights.number((fromKg(kg) * 10).rounded() / 10)
    }
}

nonisolated enum Weights {
    /// A plain number with up to two decimals and no trailing zeros, the way it's typed: "57.5", "60", "57.25".
    static func number(_ value: Double) -> String {
        var text = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), (value * 100).rounded() / 100)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }
}
