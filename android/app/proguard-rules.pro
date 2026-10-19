# shared_preferences_android calls these classes from Dart over JNI, so R8
# can't see the callers. Its suspend methods take a kotlin Continuation, which
# must keep its real name too, or startup crashes with NoSuchMethodError.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$* { *; }
