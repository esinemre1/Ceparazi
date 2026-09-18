package com.esinemre.ceparazi

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun MetricCard(title:String, value:String, subtitle:String?=null, modifier:Modifier=Modifier){
    Card(modifier, shape=RoundedCornerShape(16.dp)){
        Column(Modifier.padding(14.dp)){
            Text(title,style=MaterialTheme.typography.labelMedium)
            Text(value,style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold)
            subtitle?.let{Text(it,style=MaterialTheme.typography.bodySmall)}
        }
    }
}
@Composable
fun SectionTitle(title:String, action:String?=null, onAction:(()->Unit)?=null){
    Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){
        Text(title,style=MaterialTheme.typography.titleMedium,fontWeight=FontWeight.Bold,modifier=Modifier.weight(1f))
        if(action!=null&&onAction!=null) TextButton(onClick=onAction){Text(action)}
    }
}
@Composable
fun AccuracyBadge(meters:Float?){
    val text=meters?.let{"GPS ±%.1f m".format(it)}?:"GPS bekleniyor"
    AssistChip(onClick={},label={Text(text)})
}
