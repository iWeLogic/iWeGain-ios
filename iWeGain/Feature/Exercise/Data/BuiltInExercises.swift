import Foundation

/// The exercises shipped with the app (Figma: Components > Exercise Icons), the same list as Android.
/// Only custom exercises are stored in the database. Names come from the String Catalog, so they follow
/// the app language. Ids never change: trainings and workouts refer to them, so an id that ever shipped stays.
enum BuiltInExercises {

    /// What the library offers, grouped by muscle in the Figma order.
    static func library() -> [Exercise] { all.map { $0.exercise } }

    /// A built-in exercise, or nil for a custom id.
    static func exercise(id: String) -> Exercise? { byId[id]?.exercise }

    private static let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    private static let all: [BuiltInExercise] = [
        // Legs
        BuiltInExercise(id: "back_squat", name: "ex_name_back_squat", muscleGroup: .legs, equipment: .barbell, image: "ic_ex_barbell_squat"),
        BuiltInExercise(id: "front_squat", name: "ex_name_front_squat", muscleGroup: .legs, equipment: .barbell, image: "ic_ex_front_squat"),
        BuiltInExercise(id: "smith_machine_squat", name: "ex_name_smith_machine_squat", muscleGroup: .legs, equipment: .machine, image: "ic_ex_smith_machine_squat"),
        BuiltInExercise(id: "hack_squat", name: "ex_name_hack_squat", muscleGroup: .legs, equipment: .machine, image: "ic_ex_hack_squat"),
        BuiltInExercise(id: "leg_press", name: "ex_name_leg_press", muscleGroup: .legs, equipment: .machine, image: "ic_ex_leg_press"),
        BuiltInExercise(id: "bulgarian_split_squat", name: "ex_name_bulgarian_split_squat", muscleGroup: .legs, equipment: .dumbbells, image: "ic_ex_bulgarian_split_squat"),
        BuiltInExercise(id: "walking_lunge", name: "ex_name_walking_lunge", muscleGroup: .legs, equipment: .dumbbells, image: "ic_ex_lunge"),
        BuiltInExercise(id: "romanian_deadlift", name: "ex_name_romanian_deadlift", muscleGroup: .legs, equipment: .barbell, image: "ic_ex_romanian_deadlift"),
        BuiltInExercise(id: "deadlift", name: "ex_name_deadlift", muscleGroup: .legs, equipment: .barbell, image: "ic_ex_deadlift"),
        BuiltInExercise(id: "stiff_leg_deadlift", name: "ex_name_stiff_leg_deadlift", muscleGroup: .legs, equipment: .barbell, image: "ic_ex_stiff_leg_deadlift"),
        BuiltInExercise(id: "barbell_glute_bridge", name: "ex_name_barbell_glute_bridge", muscleGroup: .legs, equipment: .barbell, image: "ic_ex_barbell_glute_bridge"),
        BuiltInExercise(id: "cable_hip_extension", name: "ex_name_cable_hip_extension", muscleGroup: .legs, equipment: .cable, image: "ic_ex_cable_hip_extension"),
        BuiltInExercise(id: "leg_curl", name: "ex_name_leg_curl", muscleGroup: .legs, equipment: .machine, image: "ic_ex_leg_curl"),
        BuiltInExercise(id: "leg_extension", name: "ex_name_leg_extension", muscleGroup: .legs, equipment: .machine, image: "ic_ex_leg_extension"),
        BuiltInExercise(id: "calf_raise", name: "ex_name_calf_raise", muscleGroup: .legs, equipment: .machine, image: "ic_ex_calf_raise"),
        // Chest
        BuiltInExercise(id: "bench_press", name: "ex_name_bench_press", muscleGroup: .chest, equipment: .barbell, image: "ic_ex_barbell_bench_press"),
        BuiltInExercise(id: "incline_barbell_bench_press", name: "ex_name_incline_barbell_bench_press", muscleGroup: .chest, equipment: .barbell, image: "ic_ex_incline_barbell_bench_press"),
        BuiltInExercise(id: "decline_barbell_bench_press", name: "ex_name_decline_barbell_bench_press", muscleGroup: .chest, equipment: .barbell, image: "ic_ex_decline_barbell_bench_press"),
        BuiltInExercise(id: "dumbbell_bench_press", name: "ex_name_dumbbell_bench_press", muscleGroup: .chest, equipment: .dumbbells, image: "ic_ex_dumbbell_bench_press"),
        BuiltInExercise(id: "incline_dumbbell_press", name: "ex_name_incline_dumbbell_press", muscleGroup: .chest, equipment: .dumbbells, image: "ic_ex_incline_dumbbell_press"),
        BuiltInExercise(id: "decline_dumbbell_press", name: "ex_name_decline_dumbbell_press", muscleGroup: .chest, equipment: .dumbbells, image: "ic_ex_decline_dumbbell_press"),
        BuiltInExercise(id: "machine_chest_press", name: "ex_name_machine_chest_press", muscleGroup: .chest, equipment: .machine, image: "ic_ex_machine_chest_press"),
        BuiltInExercise(id: "incline_machine_chest_press", name: "ex_name_incline_machine_chest_press", muscleGroup: .chest, equipment: .machine, image: "ic_ex_incline_machine_chest_press"),
        BuiltInExercise(id: "decline_machine_chest_press", name: "ex_name_decline_machine_chest_press", muscleGroup: .chest, equipment: .machine, image: "ic_ex_decline_machine_chest_press"),
        BuiltInExercise(id: "smith_machine_bench_press", name: "ex_name_smith_machine_bench_press", muscleGroup: .chest, equipment: .machine, image: "ic_ex_smith_machine_bench_press"),
        BuiltInExercise(id: "push_up", name: "ex_name_push_up", muscleGroup: .chest, equipment: .bodyweight, image: "ic_ex_push_up"),
        BuiltInExercise(id: "dumbbell_fly", name: "ex_name_dumbbell_fly", muscleGroup: .chest, equipment: .dumbbells, image: "ic_ex_dumbbell_fly"),
        BuiltInExercise(id: "machine_fly", name: "ex_name_machine_fly", muscleGroup: .chest, equipment: .machine, image: "ic_ex_machine_fly"),
        BuiltInExercise(id: "cable_crossover_high_to_low", name: "ex_name_cable_crossover_high_to_low", muscleGroup: .chest, equipment: .cable, image: "ic_ex_cable_crossover_high_to_low"),
        BuiltInExercise(id: "cable_crossover_low_to_high", name: "ex_name_cable_crossover_low_to_high", muscleGroup: .chest, equipment: .cable, image: "ic_ex_cable_crossover_low_to_high"),
        BuiltInExercise(id: "cable_chest_fly", name: "ex_name_cable_chest_fly", muscleGroup: .chest, equipment: .cable, image: "ic_ex_cable_crossover_chest_level"),
        // Back
        BuiltInExercise(id: "pull_up", name: "ex_name_pull_up", muscleGroup: .back, equipment: .bodyweight, image: "ic_ex_pull_up"),
        BuiltInExercise(id: "lat_pulldown", name: "ex_name_lat_pulldown", muscleGroup: .back, equipment: .cable, image: "ic_ex_lat_pulldown"),
        BuiltInExercise(id: "behind_the_neck_lat_pulldown", name: "ex_name_behind_the_neck_lat_pulldown", muscleGroup: .back, equipment: .cable, image: "ic_ex_behind_the_neck_lat_pulldown"),
        BuiltInExercise(id: "seated_cable_row", name: "ex_name_seated_cable_row", muscleGroup: .back, equipment: .cable, image: "ic_ex_seated_cable_row"),
        BuiltInExercise(id: "t_bar_row", name: "ex_name_t_bar_row", muscleGroup: .back, equipment: .barbell, image: "ic_ex_t_bar_row"),
        BuiltInExercise(id: "barbell_row", name: "ex_name_barbell_row", muscleGroup: .back, equipment: .barbell, image: "ic_ex_bent_over_barbell_row"),
        BuiltInExercise(id: "one_arm_dumbbell_row", name: "ex_name_one_arm_dumbbell_row", muscleGroup: .back, equipment: .dumbbells, image: "ic_ex_one_arm_dumbbell_row"),
        BuiltInExercise(id: "incline_bench_dumbbell_row", name: "ex_name_incline_bench_dumbbell_row", muscleGroup: .back, equipment: .dumbbells, image: "ic_ex_incline_bench_dumbbell_row"),
        BuiltInExercise(id: "chest_supported_machine_row", name: "ex_name_chest_supported_machine_row", muscleGroup: .back, equipment: .machine, image: "ic_ex_chest_supported_machine_row"),
        BuiltInExercise(id: "dumbbell_pullover", name: "ex_name_dumbbell_pullover", muscleGroup: .back, equipment: .dumbbells, image: "ic_ex_dumbbell_pullover"),
        BuiltInExercise(id: "cable_pullover", name: "ex_name_cable_pullover", muscleGroup: .back, equipment: .cable, image: "ic_ex_cable_pullover"),
        BuiltInExercise(id: "barbell_shrug", name: "ex_name_barbell_shrug", muscleGroup: .back, equipment: .barbell, image: "ic_ex_barbell_shrug"),
        BuiltInExercise(id: "dumbbell_shrug", name: "ex_name_dumbbell_shrug", muscleGroup: .back, equipment: .dumbbells, image: "ic_ex_dumbbell_shrug"),
        // Shoulders
        BuiltInExercise(id: "overhead_press", name: "ex_name_overhead_press", muscleGroup: .shoulders, equipment: .barbell, image: "ic_ex_overhead_barbell_press"),
        BuiltInExercise(id: "military_press", name: "ex_name_military_press", muscleGroup: .shoulders, equipment: .barbell, image: "ic_ex_military_press"),
        BuiltInExercise(id: "dumbbell_shoulder_press", name: "ex_name_dumbbell_shoulder_press", muscleGroup: .shoulders, equipment: .dumbbells, image: "ic_ex_dumbbell_shoulder_press"),
        BuiltInExercise(id: "machine_shoulder_press", name: "ex_name_machine_shoulder_press", muscleGroup: .shoulders, equipment: .machine, image: "ic_ex_machine_shoulder_press"),
        BuiltInExercise(id: "arnold_press", name: "ex_name_arnold_press", muscleGroup: .shoulders, equipment: .dumbbells, image: "ic_ex_arnold_press"),
        BuiltInExercise(id: "lateral_raise", name: "ex_name_lateral_raise", muscleGroup: .shoulders, equipment: .dumbbells, image: "ic_ex_dumbbell_lateral_raise"),
        BuiltInExercise(id: "bent_over_lateral_raise", name: "ex_name_bent_over_lateral_raise", muscleGroup: .shoulders, equipment: .dumbbells, image: "ic_ex_bent_over_lateral_raise"),
        BuiltInExercise(id: "rear_delt_machine_fly", name: "ex_name_rear_delt_machine_fly", muscleGroup: .shoulders, equipment: .machine, image: "ic_ex_rear_delt_machine_fly"),
        BuiltInExercise(id: "dumbbell_front_raise", name: "ex_name_dumbbell_front_raise", muscleGroup: .shoulders, equipment: .dumbbells, image: "ic_ex_dumbbell_front_raise"),
        BuiltInExercise(id: "plate_front_raise", name: "ex_name_plate_front_raise", muscleGroup: .shoulders, equipment: .barbell, image: "ic_ex_plate_front_raise"),
        BuiltInExercise(id: "cable_lateral_raise", name: "ex_name_cable_lateral_raise", muscleGroup: .shoulders, equipment: .cable, image: "ic_ex_cable_lateral_raise"),
        BuiltInExercise(id: "barbell_upright_row", name: "ex_name_barbell_upright_row", muscleGroup: .shoulders, equipment: .barbell, image: "ic_ex_barbell_upright_row"),
        BuiltInExercise(id: "face_pull", name: "ex_name_face_pull", muscleGroup: .shoulders, equipment: .cable, image: "ic_ex_face_pull"),
        BuiltInExercise(id: "rope_face_pull", name: "ex_name_rope_face_pull", muscleGroup: .shoulders, equipment: .cable, image: "ic_ex_rope_face_pull"),
        // Arms: biceps, then triceps
        BuiltInExercise(id: "barbell_curl", name: "ex_name_barbell_curl", muscleGroup: .arms, equipment: .barbell, image: "ic_ex_barbell_curl"),
        BuiltInExercise(id: "ez_bar_curl", name: "ex_name_ez_bar_curl", muscleGroup: .arms, equipment: .barbell, image: "ic_ex_ez_bar_curl"),
        BuiltInExercise(id: "dumbbell_curl", name: "ex_name_dumbbell_curl", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_dumbbell_curl"),
        BuiltInExercise(id: "hammer_curl", name: "ex_name_hammer_curl", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_hammer_curl"),
        BuiltInExercise(id: "seated_dumbbell_curl", name: "ex_name_seated_dumbbell_curl", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_seated_dumbbell_curl"),
        BuiltInExercise(id: "concentration_curl", name: "ex_name_concentration_curl", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_concentration_curl"),
        BuiltInExercise(id: "preacher_curl", name: "ex_name_preacher_curl", muscleGroup: .arms, equipment: .barbell, image: "ic_ex_preacher_curl"),
        BuiltInExercise(id: "machine_curl", name: "ex_name_machine_curl", muscleGroup: .arms, equipment: .machine, image: "ic_ex_machine_curl"),
        BuiltInExercise(id: "cable_curl", name: "ex_name_cable_curl", muscleGroup: .arms, equipment: .cable, image: "ic_ex_cable_curl"),
        BuiltInExercise(id: "incline_dumbbell_curl", name: "ex_name_incline_dumbbell_curl", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_incline_dumbbell_curl"),
        BuiltInExercise(id: "close_grip_bench_press", name: "ex_name_close_grip_bench_press", muscleGroup: .arms, equipment: .barbell, image: "ic_ex_close_grip_bench_press"),
        BuiltInExercise(id: "barbell_skull_crusher", name: "ex_name_barbell_skull_crusher", muscleGroup: .arms, equipment: .barbell, image: "ic_ex_barbell_skull_crusher"),
        BuiltInExercise(id: "dumbbell_skull_crusher", name: "ex_name_dumbbell_skull_crusher", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_dumbbell_skull_crusher"),
        BuiltInExercise(id: "triceps_pushdown", name: "ex_name_triceps_pushdown", muscleGroup: .arms, equipment: .cable, image: "ic_ex_triceps_pushdown"),
        BuiltInExercise(id: "rope_triceps_pushdown", name: "ex_name_rope_triceps_pushdown", muscleGroup: .arms, equipment: .cable, image: "ic_ex_rope_triceps_pushdown"),
        BuiltInExercise(id: "one_arm_cable_extension", name: "ex_name_one_arm_cable_extension", muscleGroup: .arms, equipment: .cable, image: "ic_ex_one_arm_cable_extension"),
        BuiltInExercise(id: "overhead_rope_extension", name: "ex_name_overhead_rope_extension", muscleGroup: .arms, equipment: .cable, image: "ic_ex_overhead_rope_extension"),
        BuiltInExercise(id: "overhead_dumbbell_extension", name: "ex_name_overhead_dumbbell_extension", muscleGroup: .arms, equipment: .dumbbells, image: "ic_ex_overhead_dumbbell_extension"),
        BuiltInExercise(id: "parallel_bar_dips", name: "ex_name_parallel_bar_dips", muscleGroup: .arms, equipment: .bodyweight, image: "ic_ex_parallel_bar_dips"),
        BuiltInExercise(id: "bench_dips", name: "ex_name_bench_dips", muscleGroup: .arms, equipment: .bodyweight, image: "ic_ex_bench_dips"),
        // Abs & core
        BuiltInExercise(id: "floor_crunch", name: "ex_name_floor_crunch", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_floor_crunch"),
        BuiltInExercise(id: "bench_crunch", name: "ex_name_bench_crunch", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_bench_crunch"),
        BuiltInExercise(id: "machine_crunch", name: "ex_name_machine_crunch", muscleGroup: .core, equipment: .machine, image: "ic_ex_machine_crunch"),
        BuiltInExercise(id: "cable_crunch", name: "ex_name_cable_crunch", muscleGroup: .core, equipment: .cable, image: "ic_ex_cable_crunch"),
        BuiltInExercise(id: "hanging_leg_raise", name: "ex_name_hanging_leg_raise", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_hanging_leg_raise"),
        BuiltInExercise(id: "hanging_knee_raise", name: "ex_name_hanging_knee_raise", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_hanging_knee_raise"),
        BuiltInExercise(id: "lying_leg_raise", name: "ex_name_lying_leg_raise", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_lying_leg_raise"),
        BuiltInExercise(id: "plank", name: "ex_name_plank", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_plank"),
        BuiltInExercise(id: "side_plank", name: "ex_name_side_plank", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_side_plank"),
        BuiltInExercise(id: "russian_twist", name: "ex_name_russian_twist", muscleGroup: .core, equipment: .bodyweight, image: "ic_ex_russian_twist"),
    ]
}

private struct BuiltInExercise {
    let id: String
    let name: String.LocalizationValue
    let muscleGroup: MuscleGroup
    let equipment: Equipment
    let image: String

    var exercise: Exercise {
        Exercise(id: id, name: String(localized: name), muscleGroup: muscleGroup, equipment: equipment, builtInImage: image)
    }
}
