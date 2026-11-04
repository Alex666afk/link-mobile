# Tor's native code finds these classes, fields and methods by name, so release builds must not rename them.
-keep class org.torproject.jni.** { *; }
-keep class net.freehaven.tor.control.** { *; }
