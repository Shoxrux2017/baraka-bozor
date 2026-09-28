package uz.barakabozor.app

import android.app.Application
import com.yandex.mapkit.MapKitFactory

/**
 * Hands Yandex MapKit its API key before any map exists, as the SDK
 * requires. The key comes from the build (`--dart-define=YANDEX_MAPKIT_API_KEY`)
 * and is never committed. The yandex_mapkit plugin initialises MapKit when it
 * registers, and MapKit refuses to initialise without a key; a build without
 * one never shows a map — the Dart side offers the coordinates as fields — so
 * it gets a placeholder that lets the plugin register (`DL-33` (4)), and
 * [MainActivity] then keeps MapKit from starting (`DL-53` (1)).
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey(BuildConfig.YANDEX_MAPKIT_API_KEY.ifEmpty { KEYLESS })
    }

    private companion object {
        const val KEYLESS = "keyless-build"
    }
}
