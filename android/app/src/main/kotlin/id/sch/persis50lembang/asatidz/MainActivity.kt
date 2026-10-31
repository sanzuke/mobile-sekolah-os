package id.sch.persis50lembang.asatidz

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biometric prompt) needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel pushes are delivered on (id matches the server payload and the manifest).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "general", "Pemberitahuan", NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Keputusan izin/cuti dan kabar dari sekolah" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
