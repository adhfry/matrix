# ML Kit text recognition: hanya model Latin yang dibundel; skrip lain
# dirujuk plugin sebagai compileOnly dan tidak ada saat rilis.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# WebRTC (panggilan suara LiveKit): kelas JNI dipanggil dari kode native.
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
