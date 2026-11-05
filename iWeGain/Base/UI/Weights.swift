import Foundation

nonisolated extension WeightUnit {
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
