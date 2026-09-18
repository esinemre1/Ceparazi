package com.esinemre.ceparazi

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.location.Location
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import kotlin.math.*

enum class Screen { MAP, STAKEOUT, POINTS, DRAW, FILES }
enum class DrawMode { NONE, LINE, POLYGON }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { CeparaziApp() } }
    }

    @OptIn(ExperimentalMaterial3Api::class)
    @SuppressLint("MissingPermission")
    @Composable
    private fun CeparaziApp() {
        var screen by remember { mutableStateOf(Screen.MAP) }
        var loc by remember { mutableStateOf<Location?>(null) }
        var points by remember { mutableStateOf<List<SurveyPoint>>(emptyList()) }
        var selected by remember { mutableStateOf<SurveyPoint?>(null) }
        var status by remember { mutableStateOf("NCN dosyası yüklenmedi") }
        var drawMode by remember { mutableStateOf(DrawMode.NONE) }
        var draft by remember { mutableStateOf<List<SurveyPoint>>(emptyList()) }

        val fused = remember { LocationServices.getFusedLocationProviderClient(this) }
        fun readLocation() { fused.lastLocation.addOnSuccessListener { loc = it } }

        val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { if (it) readLocation() }
        val openNcn = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            uri?.let {
                runCatching { contentResolver.openInputStream(it)?.use { s -> NcnCodec.parse(s.readBytes()) } ?: emptyList() }
                    .onSuccess { p -> points = p; status = "${p.size} nokta yüklendi"; screen = Screen.POINTS }
                    .onFailure { e -> status = "NCN okuma hatası: ${e.message ?: "bilinmeyen hata"}" }
            }
        }
        val saveNcn = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri: Uri? ->
            uri?.let {
                runCatching { contentResolver.openOutputStream(it)?.use { out -> out.write(NcnCodec.export(points)) } }
                    .onSuccess { status = "${points.size} nokta NCN olarak kaydedildi" }
                    .onFailure { e -> status = "NCN kayıt hatası: ${e.message ?: "bilinmeyen hata"}" }
            }
        }

        LaunchedEffect(Unit) {
            if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) readLocation()
            else permission.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        Scaffold(
            topBar = { TopAppBar(title = { Text("CepArazi") }, actions = { AccuracyBadge(loc?.accuracy) }) },
            bottomBar = {
                NavigationBar {
                    NavigationBarItem(screen==Screen.MAP,{screen=Screen.MAP},{Text("⌖")},label={Text("Harita")})
                    NavigationBarItem(screen==Screen.STAKEOUT,{screen=Screen.STAKEOUT},{Text("➤")},label={Text("Aplikasyon")})
                    NavigationBarItem(screen==Screen.POINTS,{screen=Screen.POINTS},{Text("●")},label={Text("Noktalar")})
                    NavigationBarItem(screen==Screen.DRAW,{screen=Screen.DRAW},{Text("✎")},label={Text("Çizim")})
                    NavigationBarItem(screen==Screen.FILES,{screen=Screen.FILES},{Text("▣")},label={Text("Dosya")})
                }
            }
        ) { pad ->
            Column(Modifier.padding(pad).padding(14.dp).fillMaxSize(), verticalArrangement=Arrangement.spacedBy(10.dp)) {
                when(screen) {
                    Screen.MAP -> {
                        SectionTitle("Harita")
                        Card(Modifier.fillMaxWidth().weight(1f)) {
                            Box(Modifier.fillMaxSize().padding(20.dp)) {
                                Column(verticalArrangement=Arrangement.spacedBy(10.dp)) {
                                    Text("Harita alanı", style=MaterialTheme.typography.headlineSmall)
                                    Text("Telefon konumu, NCN noktaları, hedef, çizgi ve poligonlar bu katmanda gösterilecek.")
                                    loc?.let { Text("Konum: %.7f, %.7f\nGPS: ±%.1f m".format(it.latitude,it.longitude,it.accuracy)) }
                                    Text("Yüklü nokta: ${points.size}")
                                }
                            }
                        }
                        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                            Button({readLocation()},Modifier.weight(1f)){Text("Konumum")}
                            OutlinedButton({screen=Screen.POINTS},Modifier.weight(1f)){Text("Noktalar")}
                            OutlinedButton({screen=Screen.DRAW},Modifier.weight(1f)){Text("Çiz")}
                        }
                    }
                    Screen.STAKEOUT -> {
                        SectionTitle("Aplikasyon")
                        if(selected==null) {
                            Text("Önce Noktalar ekranından hedef seç.")
                            Button({screen=Screen.POINTS}){Text("Hedef Seç")}
                        } else {
                            val p=selected!!
                            Text("HEDEF ${p.name}",style=MaterialTheme.typography.headlineMedium)
                            Text("Y %.3f   X %.3f".format(p.y,p.x))
                            Text("NCN hedef koordinatı proje sistemindedir. Koordinat dönüşüm motoru tamamlanmadan telefon GNSS'iyle sahte mesafe üretilmez.")
                            Button({selected=null}){Text("Hedefi Bitir")}
                        }
                    }
                    Screen.POINTS -> {
                        SectionTitle("Noktalar")
                        Text("${points.size} nokta")
                        LazyColumn(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(6.dp)) {
                            items(points){ p ->
                                Card(onClick={selected=p;screen=Screen.STAKEOUT},modifier=Modifier.fillMaxWidth()) {
                                    Column(Modifier.padding(12.dp)) {
                                        Text(p.name,style=MaterialTheme.typography.titleMedium)
                                        Text("Y %.3f   X %.3f%s".format(p.y,p.x,p.z?.let{"   Z %.3f".format(it)}?:""))
                                    }
                                }
                            }
                        }
                    }
                    Screen.DRAW -> {
                        SectionTitle("Basit Çizim")
                        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                            FilterChip(drawMode==DrawMode.LINE,{drawMode=DrawMode.LINE;draft=emptyList()},{Text("Çizgi")})
                            FilterChip(drawMode==DrawMode.POLYGON,{drawMode=DrawMode.POLYGON;draft=emptyList()},{Text("Poligon")})
                        }
                        Text(if(drawMode==DrawMode.NONE) "Çizim türünü seç." else "Harita etkileşimi bağlandığında dokunulan koordinatlar burada köşe olarak tutulacak.")
                        if(draft.isNotEmpty()) Text("Köşe: ${draft.size}")
                        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                            OutlinedButton({if(draft.isNotEmpty()) draft=draft.dropLast(1)},enabled=draft.isNotEmpty()){Text("Geri Al")}
                            OutlinedButton({draft=emptyList();drawMode=DrawMode.NONE}){Text("İptal")}
                            Button({drawMode=DrawMode.NONE},enabled=(drawMode==DrawMode.LINE&&draft.size>=2)||(drawMode==DrawMode.POLYGON&&draft.size>=3)){Text("Bitir")}
                        }
                    }
                    Screen.FILES -> {
                        SectionTitle("NCN Dosyaları")
                        Text(status)
                        Button({openNcn.launch(arrayOf("*/*"))},Modifier.fillMaxWidth()){Text("NCN İçe Aktar")}
                        OutlinedButton({saveNcn.launch("ceparazi_noktalar.ncn")},Modifier.fillMaxWidth(),enabled=points.isNotEmpty()){Text("NCN Dışa Aktar")}
                        HorizontalDivider()
                        Text("Format: Nokta No • Y • X • Z • Kod")
                    }
                }
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
