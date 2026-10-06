package za.co.afrisafety.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

// A FragmentActivity so local_auth can show Android's fingerprint prompt.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createAlertChannel()
    }

    // Keeps sharing alive when the app is swiped away from Recents.
    //
    // By default the Flutter engine (and with it the Dart code that encrypts
    // and uploads locations) dies with this activity. Here the engine lives
    // in the process instead, so it outlives the activity. The process itself
    // stays alive only while the location foreground service runs, and that
    // service always shows its notification: sharing in the background is
    // never silent (security rule 6). Reopening the app reattaches the same
    // engine, so nothing restarts.
    //
    // Because the engine comes from here, FlutterFragmentActivity (and its
    // FlutterFragment) neither destroy it with the activity nor register
    // plugins a second time.
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        return cache.get(ENGINE_ID) ?: FlutterEngine(context.applicationContext).also {
            it.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault(),
            )
            cache.put(ENGINE_ID, it)
        }
    }

    // High-importance channel for SOS alerts from Circle members, created
    // natively so it exists before the first push arrives. (minSdk 26, so
    // notification channels are always available.)
    private fun createAlertChannel() {
        val channel = NotificationChannel(
            ALERT_CHANNEL_ID,
            getString(R.string.alert_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.alert_channel_description)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    companion object {
        const val ALERT_CHANNEL_ID = "afrisafety_alerts"
        private const val ENGINE_ID = "afrisafety_main"
    }
}
