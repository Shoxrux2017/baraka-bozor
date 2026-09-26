package uz.barakabozor.app

import android.app.Application
import com.yandex.mapkit.MapKitFactory

/**
 * Hands Yandex MapKit its API key before any map exists, as the SDK
 * requires. The key comes from the build (`--dart-define=YANDEX_MAPKIT_API_KEY`)
 * and is never committed; a build without it sets nothing, and the Dart side,
 * which reads the same define, then offers the coordinates as fields instead
 * of a map (`DL-33`).
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val key = BuildConfig.YANDEX_MAPKIT_API_KEY
        if (key.isNotEmpty()) {
            MapKitFactory.setApiKey(key)
        }
    }
}
