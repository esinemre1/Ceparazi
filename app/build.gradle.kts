plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "com.esinemre.ceparazi"
    compileSdk = 35
    defaultConfig { applicationId = "com.esinemre.ceparazi"; minSdk = 26; targetSdk = 35; versionCode = 1; versionName = "2.0.0" }
    buildFeatures { compose = true }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
