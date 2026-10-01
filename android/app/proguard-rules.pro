# Reglas ProGuard/R8 para ML Kit Text Recognition.
#
# El plugin google_mlkit_text_recognition referencia las clases de los
# scripts no latinos (chino, devanagari, japonés, coreano) aunque la app
# solo use el latino. Esas clases no se incluyen, por lo que R8 las marca
# como faltantes. Se silencian con -dontwarn (no se usan en runtime).

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
