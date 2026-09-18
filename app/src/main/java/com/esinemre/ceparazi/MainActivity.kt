package com.esinemre.ceparazi

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import kotlin.math.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); setContent { MaterialTheme { CeparaziApp() } } }
    @SuppressLint("MissingPermission")
    @Composable fun CeparaziApp() {
        var loc by remember { mutableStateOf<Location?>(null) }
        var targetLat by remember { mutableStateOf("") }; var targetLon by remember { mutableStateOf("") }
        val fused = remember { LocationServices.getFusedLocationProviderClient(this) }
        fun readLocation() { fused.lastLocation.addOnSuccessListener { loc = it } }
        val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { if(it) readLocation() }
        LaunchedEffect(Unit) {
            if(ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED) readLocation()
            else permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val target = targetLat.toDoubleOrNull()?.let { a -> targetLon.toDoubleOrNull()?.let { b -> a to b } }
        val result = if(loc != null && target != null) stakeout(loc!!.latitude,loc!!.longitude,target.first,target.second) else null
        Scaffold(topBar={ TopAppBar(title={Text("CepArazi • Aplikasyon")}) }) { pad ->
            Column(Modifier.padding(pad).padding(16.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
                Text("GNSS Konumu", style=MaterialTheme.typography.titleMedium)
                Text(if(loc==null) "Konum bekleniyor…" else "Enlem: %.8f\nBoylam: %.8f\nDoğruluk: ±%.1f m".format(loc!!.latitude,loc!!.longitude,loc!!.accuracy))
                Button(onClick={readLocation()}, modifier=Modifier.fillMaxWidth()){Text("Konumu Yenile")}
                HorizontalDivider(); Text("Hedef Nokta", style=MaterialTheme.typography.titleMedium)
                OutlinedTextField(targetLat,{targetLat=it},label={Text("Enlem")},modifier=Modifier.fillMaxWidth())
                OutlinedTextField(targetLon,{targetLon=it},label={Text("Boylam")},modifier=Modifier.fillMaxWidth())
                if(result!=null) Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) {
                    Text("APLİKASYON", style=MaterialTheme.typography.titleMedium)
                    Text("Mesafe: %.2f m".format(result.first)); Text("Yön: %.2f°".format(result.second))
                }}
                Text("V2 temel sürüm • Sonraki: ITRF/ED50, DOM, DXF/KML ve RTK/NMEA")
            }
        }
    }
}
fun stakeout(lat1:Double,lon1:Double,lat2:Double,lon2:Double):Pair<Double,Double>{
    val r=6371008.8; val p1=Math.toRadians(lat1); val p2=Math.toRadians(lat2)
    val dp=Math.toRadians(lat2-lat1); val dl=Math.toRadians(lon2-lon1)
    val a=sin(dp/2).pow(2)+cos(p1)*cos(p2)*sin(dl/2).pow(2)
    val d=r*2*atan2(sqrt(a),sqrt(1-a))
    val y=sin(dl)*cos(p2); val x=cos(p1)*sin(p2)-sin(p1)*cos(p2)*cos(dl)
    return d to ((Math.toDegrees(atan2(y,x))+360)%360)
}
