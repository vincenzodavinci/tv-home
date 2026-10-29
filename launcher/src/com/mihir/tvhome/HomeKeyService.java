package com.mihir.tvhome;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.view.accessibility.AccessibilityEvent;

/**
 * Keeps this launcher as Home while the stock Google TV launcher stays enabled. The stock launcher
 * has to stay: on Google TV it opens the apps behind the remote's app buttons and owns the Settings
 * panel. But as a system app its HOME filter always outranks a third-party one, so this service
 * steps in whenever the stock home screen comes to the front (Home, Back out of an app, boot).
 * It deliberately doesn't filter key events: re-injected keys lose hold-to-repeat (volume).
 */
public class HomeKeyService extends AccessibilityService {

    static final String STOCK_LAUNCHER = "com.google.android.apps.tv.launcherx";

    @Override
    public void onAccessibilityEvent(AccessibilityEvent e) {
        if (e.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return;
        CharSequence pkg = e.getPackageName(), cls = e.getClassName();
        // Only the stock home screen itself, not its Settings panel or other windows.
        if (pkg != null && STOCK_LAUNCHER.contentEquals(pkg)
                && cls != null && cls.toString().endsWith("HomeActivity")) {
            goHome();
        }
    }

    @Override
    public void onInterrupt() { }

    private void goHome() {
        startActivity(new Intent(this, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED));
    }
}
