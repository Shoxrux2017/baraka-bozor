package uz.barakabozor.app

import android.content.Context
import com.unact.yandexmapkit.YandexMapkitPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * A build without a MapKit key never shows a map — the Dart side offers the
 * coordinates as fields — so MapKit must never start. MapKit asks Yandex
 * about the placeholder key of [MainApplication] and is refused; a MapKit
 * that was started then aborts the whole process a few seconds after
 * launch, one only initialised does not (`DL-53`).
 *
 * The yandex_mapkit plugin starts MapKit when it is attached to an
 * activity. On Flutter's own path the engine is attached to the activity
 * before the plugins register, so the plugin would start MapKit at once;
 * here such a build makes the engine itself, whose plugins register with no
 * activity yet, and takes the MapKit plugin off before the activity
 * attaches. A build with a key keeps Flutter's own path.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        if (!keyless) {
            return null
        }
        // The engine flags a run passes in the intent, as Flutter's own
        // engine takes them.
        return FlutterEngine(
            context,
            flutterShellArgs.toArray(),
            true,
            shouldRestoreAndSaveState(),
        ).also {
            it.plugins.remove(YandexMapkitPlugin::class.java)
        }
    }

    // The engine made above belongs to this activity alone, as Flutter's
    // own would.
    override fun shouldDestroyEngineWithHost(): Boolean = keyless || super.shouldDestroyEngineWithHost()

    private val keyless: Boolean
        get() = BuildConfig.YANDEX_MAPKIT_API_KEY.isEmpty()
}
