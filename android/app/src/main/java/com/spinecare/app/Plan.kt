package com.spinecare.app

import kotlinx.serialization.Serializable

@Serializable
data class FormRule(val metric: String, val maxAbs: Double, val cue: String)

@Serializable
data class Exercise(
    val id: String,
    val name: String,
    val view: String,                 // side | front | back
    val requiredLandmarks: List<String>,
    val minConf: Float,
    val signal: String,
    val repLow: Double,
    val repHigh: Double,
    val targetReps: Int,
    val formRules: List<FormRule>,
    val stopConditions: List<String>,
    val clinicianApproved: Boolean,
    val description: String,
)

/** Built-in plan mirrors server/exercises.json. In production this is fetched
 *  from the clinician backend and signed; nothing here is self-prescribed. */
object Plan {
    val exercises = listOf(
        Exercise(
            "chin_tuck", "Chin tuck (deep neck flexor)", "side",
            listOf("lear", "lsho", "lhip"), 0.5f, "head_forward_proxy", 0.02, 0.12, 10,
            listOf(FormRule("shoulder_line_tilt", 8.0, "Relax the raised shoulder; keep shoulders level."),
                   FormRule("trunk_tilt_frontal", 10.0, "Keep the trunk upright; only the head moves.")),
            listOf("arm pain increase", "tingling worsens", "dizziness"), false,
            "Gently draw the chin straight back (double-chin), keeping eyes level. Hold 3s. Move only the head."
        ),
        Exercise(
            "cervical_rotation_rom", "Cervical rotation ROM (pain-free)", "front",
            listOf("nose", "lsho", "rsho"), 0.5f, "abs:neck_yaw_est", 8.0, 35.0, 8,
            listOf(FormRule("shoulder_line_tilt", 8.0, "Do not lift the shoulder when turning; rotate through the neck only."),
                   FormRule("trunk_tilt_frontal", 8.0, "Keep the chest facing forward; isolate neck rotation.")),
            listOf("radiating arm pain", "numbness increases"), false,
            "Slowly turn the head toward each side within the pain-free range. Never push into symptoms."
        ),
        Exercise(
            "thoracic_extension", "Thoracic extension (seated)", "side",
            listOf("lear", "lsho", "lhip", "lkne"), 0.5f, "trunk_tilt_frontal", 5.0, 18.0, 10,
            listOf(FormRule("cervical_sag_proxy", 60.0, "Lead with the chest, not the head; keep the neck long.")),
            listOf("sharp neck pain", "arm symptoms"), false,
            "Sit tall, hands behind head, extend the upper back over the chair back. Keep the neck long."
        ),
        Exercise(
            "scapular_retraction", "Scapular setting", "back",
            listOf("lsho", "rsho", "lhip", "rhip"), 0.5f, "shoulder_line_tilt", 0.0, 6.0, 10,
            listOf(FormRule("trunk_tilt_frontal", 8.0, "Stay tall; do not lean.")),
            listOf("pain between shoulder blades worsening"), false,
            "Gently draw shoulder blades down and back without shrugging. Hold 5s."
        ),
    )
    fun byId(id: String) = exercises.firstOrNull { it.id == id }
}
