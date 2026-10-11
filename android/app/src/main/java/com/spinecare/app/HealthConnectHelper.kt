package com.spinecare.app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.LocalDateTime

/** Health Connect: steps import (graceful when unavailable). */
class HealthConnectHelper(private val context: Context) {
    companion object {
        val PERMISSIONS: Set<String> = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
        )
    }

    fun isAvailable(): Boolean = try {
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
    } catch (e: Exception) { false }

    /** Intent that opens the Health Connect permission picker for missing perms.
     *  The library's request contract is internal in 1.1.0-alpha06, so we build
     *  the provider intent directly; returns null when unavailable. */
    suspend fun permissionIntent() = try {
        val client = HealthConnectClient.getOrCreate(context)
        val missing = PERMISSIONS - client.permissionController.getGrantedPermissions()
        if (missing.isEmpty()) null
        else android.content.Intent("androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE")
    } catch (e: Exception) { null }

    data class DayStats(val steps: Int, val sleepMinutes: Double)

    suspend fun readToday(): DayStats? = try {
        val client = HealthConnectClient.getOrCreate(context)
        val since = LocalDateTime.now().minusDays(1)
        val resp = client.readRecords(
            ReadRecordsRequest(
                recordType = StepsRecord::class,
                timeRangeFilter = TimeRangeFilter.between(since, LocalDateTime.now())
            )
        )
        DayStats(resp.records.sumOf { it.count }.toInt(), -1.0)
    } catch (e: Exception) { null }
}
