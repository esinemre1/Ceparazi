package com.esinemre.ceparazi

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import android.net.Uri
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp\nimport androidx.compose.ui.text.font.FontWeight
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import kotlin.math.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); setContent { MaterialTheme { CeparaziApp() } } }
    @SuppressLint("MissingPermission")
    @Composable fun CeparaziApp() {
        var loc by remember { mutableStateOf<Location?>(null) }
        var targetLat by remember { mutableStateOf("") }; var targetLon by remember { mutableStateOf("") }
        var ncnPoints by remember { mutableStateOf<List<SurveyPoint>>(emptyList()) }
        var ncnStatus by remember { mutableStateOf("NCN dosyası yüklenmedi") }
        val fused = remember { LocationServices.getFusedLocationProviderClient(this) }
        fun readLocation() { fused.lastLocation.addOnSuccessListener { loc = it } }
        val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { if(it) readLocation() }
        val openNcn = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            uri?.let {
                runCatching {
                    contentResolver.openInputStream(it)?.use { input -> NcnCodec.parse(input.readBytes()) } ?: emptyList()
                }.onSuccess { pts -> ncnPoints=pts; ncnStatus="${pts.size} nokta okundu" }
                 .onFailure { e -> ncnStatus="NCN okuma hatası: ${e.message ?: "bilinmeyen hata"}" }
            }
        }
        val saveNcn = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri: Uri? ->
            uri?.let {
                runCatching { contentResolver.openOutputStream(it)?.use { out -> out.write(NcnCodec.export(ncnPoints)) } }
                    .onSuccess { ncnStatus="${ncnPoints.size} nokta NCN olarak kaydedildi" }
                    .onFailure { e -> ncnStatus="NCN kayıt hatası: ${e.message ?: "bilinmeyen hata"}" }
            }
        }
        LaunchedEffect(Unit) {
            if(ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED) readLocation()
            else permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        val target = targetLat.toDoubleOrNull()?.let { a -> targetLon.toDoubleOrNull()?.let { b -> a to b } }
        val result = if(loc != null && target != null) stakeout(loc!!.latitude,loc!!.longitude,target.first,target.second) else null
        val grid = loc?.let { wgs84ToUtm(it.latitude,it.longitude) }
        Scaffold(topBar={ TopAppBar(title={Text("CepArazi • Aplikasyon")}) }) { pad ->
            Column(Modifier.padding(pad).padding(16.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
                SectionTitle("Saha Konumu")\n                AccuracyBadge(loc?.accuracy)
                Text(if(loc==null) "Konum bekleniyor…" else "Enlem: %.8f
Boylam: %.8f
Doğruluk: ±%.1f m".format(loc!!.latitude,loc!!.longitude,loc!!.accuracy))
                Button(onClick={readLocation()}, modifier=Modifier.fillMaxWidth()){Text("Konumu Yenile")}
                grid?.let { Text("UTM Zon: ${it.zone}N • DOM: ${it.dom}°\
Y (E): %.3f m\
X (N): %.3f m".format(it.easting,it.northing)) }
                HorizontalDivider()
                Text("NCN Nokta Dosyası", style=MaterialTheme.typography.titleMedium)
                Row(Modifier.fillMaxWidth(), horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                    Button(onClick={openNcn.launch(arrayOf("*/*"))}, modifier=Modifier.weight(1f)){Text("NCN Aç")}
                    OutlinedButton(onClick={saveNcn.launch("ceparazi_noktalar.ncn")}, enabled=ncnPoints.isNotEmpty(), modifier=Modifier.weight(1f)){Text("NCN Kaydet")}
                }
                Text(ncnStatus)
                if(ncnPoints.isNotEmpty()) {
                    Text("İlk noktalar:", style=MaterialTheme.typography.labelLarge)
                    ncnPoints.take(5).forEach { p ->
                        Card(Modifier.fillMaxWidth()) { Row(Modifier.padding(10.dp), horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                            Text(p.name, modifier=Modifier.width(70.dp)); Text("Y %.3f   X %.3f".format(p.y,p.x))
                        }}
                    }
                }
                HorizontalDivider(); SectionTitle("Hedef / Aplikasyon")
                OutlinedTextField(targetLat,{targetLat=it},label={Text("Enlem")},modifier=Modifier.fillMaxWidth())
                OutlinedTextField(targetLon,{targetLon=it},label={Text("Boylam")},modifier=Modifier.fillMaxWidth())
                if(result!=null) Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) {
                    Text("APLİKASYON", style=MaterialTheme.typography.titleMedium, fontWeight=androidx.compose.ui.text.font.FontWeight.Bold)
                    Text("Mesafe: %.3f m".format(result.first)); Text("Azimut: %.4f°".format(result.second))
                    val br=Math.toRadians(result.second); Text("ΔX (Kuzey): %+.3f m".format(result.first*kotlin.math.cos(br))); Text("ΔY (Doğu): %+.3f m".format(result.first*kotlin.math.sin(br)))
                }}
                Text("V2 • Telefon GNSS • UTM/DOM • NCN içe/dışa aktarma")
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


data class GridPoint(val easting:Double,val northing:Double,val zone:Int,val dom:Int)
fun wgs84ToUtm(lat:Double,lon:Double):GridPoint {
    val a=6378137.0; val f=1.0/298.257223563; val k0=0.9996
    val e2=f*(2-f); val ep2=e2/(1-e2)
    val zone=kotlin.math.floor((lon+180)/6).toInt()+1
    val dom=(zone-1)*6-180+3
    val p=Math.toRadians(lat); val dl=Math.toRadians(lon-dom)
    val n=a/kotlin.math.sqrt(1-e2*kotlin.math.sin(p).pow(2))
    val t=kotlin.math.tan(p).pow(2); val cc=ep2*kotlin.math.cos(p).pow(2); val aa=kotlin.math.cos(p)*dl
    val m=a*((1-e2/4-3*e2.pow(2)/64-5*e2.pow(3)/256)*p-(3*e2/8+3*e2.pow(2)/32+45*e2.pow(3)/1024)*kotlin.math.sin(2*p)+(15*e2.pow(2)/256+45*e2.pow(3)/1024)*kotlin.math.sin(4*p)-(35*e2.pow(3)/3072)*kotlin.math.sin(6*p))
    val east=500000+k0*n*(aa+(1-t+cc)*aa.pow(3)/6+(5-18*t+t.pow(2)+72*cc-58*ep2)*aa.pow(5)/120)
    var north=k0*(m+n*kotlin.math.tan(p)*(aa.pow(2)/2+(5-t+9*cc+4*cc.pow(2))*aa.pow(4)/24+(61-58*t+t.pow(2)+600*cc-330*ep2)*aa.pow(6)/720))
    if(lat<0) north+=10000000
    return GridPoint(east,north,zone,dom)
}
