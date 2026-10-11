import Foundation

struct FormRule: Codable { let metric: String; let maxAbs: Double; let cue: String }

struct Exercise: Codable, Identifiable {
    let id: String
    let name: String
    let view: String                    // side | front | back
    let requiredLandmarks: [String]
    let minConf: Double
    let signal: String
    let repLow: Double
    let repHigh: Double
    let targetReps: Int
    let formRules: [FormRule]
    let stopConditions: [String]
    let clinicianApproved: Bool
    let description: String
}

/// Built-in plan mirrors server/exercises.json and Android Plan.kt.
/// In production this is fetched from the clinician backend and signed;
/// nothing here is self-prescribed.
enum Plan {
    static let exercises: [Exercise] = [
        Exercise(
            id: "chin_tuck", name: "Chin tuck (deep neck flexor)", view: "side",
            requiredLandmarks: ["lear", "lsho", "lhip"], minConf: 0.5,
            signal: "head_forward_proxy", repLow: 0.02, repHigh: 0.12, targetReps: 10,
            formRules: [FormRule(metric: "shoulder_line_tilt", maxAbs: 8, cue: "Relax the raised shoulder; keep shoulders level."),
                        FormRule(metric: "trunk_tilt_frontal", maxAbs: 10, cue: "Keep the trunk upright; only the head moves.")],
            stopConditions: ["arm pain increase", "tingling worsens", "dizziness"],
            clinicianApproved: false,
            description: "Gently draw the chin straight back (double-chin), keeping eyes level. Hold 3s. Move only the head."),
        Exercise(
            id: "cervical_rotation_rom", name: "Cervical rotation ROM (pain-free)", view: "front",
            requiredLandmarks: ["nose", "lsho", "rsho"], minConf: 0.5,
            signal: "abs:neck_yaw_est", repLow: 8, repHigh: 35, targetReps: 8,
            formRules: [FormRule(metric: "shoulder_line_tilt", maxAbs: 8, cue: "Do not lift the shoulder when turning; rotate through the neck only."),
                        FormRule(metric: "trunk_tilt_frontal", maxAbs: 8, cue: "Keep the chest facing forward; isolate neck rotation.")],
            stopConditions: ["radiating arm pain", "numbness increases"],
            clinicianApproved: false,
            description: "Slowly turn the head toward each side within the pain-free range. Never push into symptoms."),
        Exercise(
            id: "thoracic_extension", name: "Thoracic extension (seated)", view: "side",
            requiredLandmarks: ["lear", "lsho", "lhip", "lknee"], minConf: 0.5,
            signal: "trunk_tilt_frontal", repLow: 5, repHigh: 18, targetReps: 10,
            formRules: [FormRule(metric: "cervical_sag_proxy", maxAbs: 60, cue: "Lead with the chest, not the head; keep the neck long.")],
            stopConditions: ["sharp neck pain", "arm symptoms"],
            clinicianApproved: false,
            description: "Sit tall, hands behind head, extend the upper back over the chair back. Keep the neck long."),
        Exercise(
            id: "scapular_retraction", name: "Scapular setting", view: "back",
            requiredLandmarks: ["lsho", "rsho", "lhip", "rhip"], minConf: 0.5,
            signal: "shoulder_line_tilt", repLow: 0, repHigh: 6, targetReps: 10,
            formRules: [FormRule(metric: "trunk_tilt_frontal", maxAbs: 8, cue: "Stay tall; do not lean.")],
            stopConditions: ["pain between shoulder blades worsening"],
            clinicianApproved: false,
            description: "Gently draw shoulder blades down and back without shrugging. Hold 5s."),
    ]
    static func byId(_ id: String) -> Exercise? { exercises.first { $0.id == id } }
}
