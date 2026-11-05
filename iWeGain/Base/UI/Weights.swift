import Foundation

nonisolated enum Weights {
    /// A plain number with up to two decimals and no trailing zeros, the way it's typed: "57.5", "60", "57.25".
    static func number(_ value: Double) -> String {
        var text = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), (value * 100).rounded() / 100)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }
}

nonisolated extension WeightUnit {
    /// [kg] shown in this unit: kilograms to 0.01 so 0.25 kg steps show exactly ("57.25"), pounds to 0.1
    /// (converted from kilograms they rarely land on a round number): "126.8".
    func weightNumber(_ kg: Double) -> String {
        self == .kg ? Weights.number(kg) : Weights.number((fromKg(kg) * 10).rounded() / 10)
    }

    /// "57.5 kg" / "126.8 lb".
    func weightText(_ kg: Double) -> String {
        Strings.format(self == .kg ? "weight_kg" : "weight_lb", weightNumber(kg))
    }

    /// "57.5 kg × 8".
    func setResultText(_ kg: Double, reps: Int) -> String {
        Strings.format(self == .kg ? "set_result_kg" : "set_result_lb", weightNumber(kg), reps)
    }

    /// "1,240 kg": a total, rounded to whole units with grouping.
    func volumeText(_ kg: Double) -> String {
        let value = Int(fromKg(kg).rounded()).formatted(.number.grouping(.automatic))
        return Strings.format(self == .kg ? "weight_kg" : "weight_lb", value)
    }
}
