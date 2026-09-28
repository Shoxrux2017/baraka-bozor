package uz.barakabozor.app

import com.unact.yandexmapkit.YandexMapkitPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * A build without a MapKit key never shows a map — the Dart side offers the
 * coordinates as fields — so the MapKit plugin leaves the engine before the
 * activity starts it. Started, MapKit asks Yandex about the placeholder key
 * of [MainApplication], and Yandex's refusal aborts the whole process a few
 * seconds after launch (`DL-53`).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (BuildConfig.YANDEX_MAPKIT_API_KEY.isEmpty()) {
            flutterEngine.plugins.remove(YandexMapkitPlugin::class.java)
        }
    }
}
