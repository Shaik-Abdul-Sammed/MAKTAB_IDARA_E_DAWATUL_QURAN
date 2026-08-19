# Proguard rules for Maktab App
# Keep SQLCipher and MLKit native classes intact

-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Keep MLKit classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# Flutter contacts keep rules
-keep class com.github.clans.fab.** { *; }
