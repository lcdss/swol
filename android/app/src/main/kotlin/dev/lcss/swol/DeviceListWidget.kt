package dev.lcss.swol

import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.material3.ColorProviders
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import org.json.JSONArray

/**
 * Renders the saved device list. Tapping a row broadcasts back into the Dart
 * background callback, which sends the wake packets and reports progress
 * through the "statusKind"/"statusName" entries; the Flutter side keeps the
 * "devices" entry in sync with the app's storage.
 */
class DeviceListWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme(
                colors = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    GlanceTheme.colors
                } else {
                    FallbackColors
                },
            ) {
                WidgetContent(currentState())
            }
        }
    }
}

// The app's own palette, for devices without Material You. From 12 on the
// widget follows the wallpaper like the app does.
private val FallbackColors = ColorProviders(
    light = lightColorScheme(
        primary = Color(0xFF287980),
        surface = Color(0xFFF3EDF7),
        onSurface = Color(0xFF1D1B20),
        onSurfaceVariant = Color(0xFF49454F),
    ),
    dark = darkColorScheme(
        primary = Color(0xFF5BC0C9),
        surface = Color(0xFF211F26),
        onSurface = Color(0xFFE6E0E9),
        onSurfaceVariant = Color(0xFFCAC4D0),
    ),
)

@Composable
private fun WidgetContent(state: HomeWidgetGlanceState) {
    val context = LocalContext.current
    val devices = JSONArray(state.preferences.getString("devices", null) ?: "[]")
    val statusKind = state.preferences.getString("statusKind", null)
    val statusName = state.preferences.getString("statusName", null)

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.surface)
            .cornerRadius(16.dp)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>(context)),
    ) {
        Text(
            context.getString(R.string.widget_title),
            style = TextStyle(
                color = GlanceTheme.colors.primary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            ),
        )

        val status = when {
            statusName == null -> null
            statusKind == "waking" -> context.getString(R.string.widget_waking, statusName)
            statusKind == "failed" -> context.getString(R.string.widget_wake_failed, statusName)
            else -> null
        }
        if (status != null) {
            Text(
                status,
                style = TextStyle(
                    color = GlanceTheme.colors.onSurfaceVariant,
                    fontSize = 12.sp,
                ),
            )
        }

        if (devices.length() == 0) {
            Text(
                context.getString(R.string.widget_empty),
                style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 13.sp),
                modifier = GlanceModifier.padding(top = 8.dp),
            )
        } else {
            LazyColumn(modifier = GlanceModifier.padding(top = 4.dp)) {
                items(count = devices.length(), itemId = { it.toLong() }) { index ->
                    val device = devices.getJSONObject(index)
                    DeviceRow(
                        id = device.getString("id"),
                        name = device.getString("hostName"),
                    )
                }
            }
        }
    }
}

@Composable
private fun DeviceRow(id: String, name: String) {
    Row(
        verticalAlignment = Alignment.Vertical.CenterVertically,
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clickable(
                actionRunCallback<WakeDeviceAction>(
                    actionParametersOf(WakeDeviceAction.deviceId to id),
                ),
            ),
    ) {
        Image(
            provider = ImageProvider(R.drawable.ic_widget_power),
            contentDescription = LocalContext.current.getString(R.string.widget_wake),
            colorFilter = ColorFilter.tint(GlanceTheme.colors.primary),
            modifier = GlanceModifier.size(20.dp),
        )
        Spacer(modifier = GlanceModifier.width(10.dp))
        Text(
            name,
            maxLines = 1,
            style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 15.sp),
        )
    }
}

class WakeDeviceAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val id = parameters[deviceId] ?: return

        HomeWidgetBackgroundIntent
            .getBroadcast(context, Uri.parse("swol://wake?id=" + Uri.encode(id)))
            .send()
    }

    companion object {
        val deviceId = ActionParameters.Key<String>("deviceId")
    }
}
