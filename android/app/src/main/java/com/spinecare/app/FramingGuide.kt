package com.spinecare.app

/** Maps exercise view + required landmarks to concrete camera-placement guidance. */
object FramingGuide {
    data class Guide(val headline: String, val steps: List<String>)

    fun forView(view: String): Guide = when (view) {
        "side" -> Guide(
            "Side view — place the phone on a table at chest height, ~2 m away",
            listOf(
                "Stand/sit in profile so the whole side of your body is visible.",
                "Camera lens level with your chest, pointing straight at you.",
                "Required in frame: ear, shoulder, hip and knee when listed.",
                "Good even lighting on your body; avoid backlight from windows.",
            )
        )
        "front" -> Guide(
            "Front view — phone ~2 m away, lens at face height",
            listOf(
                "Face the camera directly; both shoulders and both ears visible.",
                "Leave space above the head and below the hips.",
                "Avoid turning your torso; the app measures neck rotation, not body rotation.",
            )
        )
        "back" -> Guide(
            "Back view — use a mirror or a helper, or a second phone",
            listOf(
                "Back to the camera; both shoulders and hips visible.",
                "A full-length mirror in front of you lets the phone see your back via reflection.",
                "Keep the upper back evenly lit.",
            )
        )
        else -> Guide("Position the camera so the required body parts are fully visible.", listOf("Follow the on-screen outline."))
    }

    /** Human-readable correction for a framing issue. */
    fun fixFor(issue: String): String = when {
        issue.endsWith(":low_conf") -> "Landmark not clearly detected — improve lighting or move closer."
        issue.endsWith(":out_of_frame") -> "A required body part is near the edge — step back or re-center."
        issue == "no_person" -> "No person detected — stand in view of the camera."
        else -> "Adjust the camera until the outline turns green."
    }
}
