package com.esinemre.ceparazi

import java.nio.charset.Charset

data class SurveyPoint(val name:String, val y:Double, val x:Double, val z:Double?=null, val code:String?=null)

object NcnCodec {
    // Yaygın Netcad ASCII nokta satırlarını toleranslı okur:
    // NO Y X [Z] [KOD] ; ayraç olarak boşluk, tab, virgül veya noktalı virgül.
    fun parse(bytes:ByteArray):List<SurveyPoint> {
        val text = decode(bytes)
        return text.lineSequence().mapNotNull(::parseLine).toList()
    }
    private fun decode(b:ByteArray):String = try { b.toString(Charsets.UTF_8) }
        catch (_:Exception) { b.toString(Charset.forName("windows-1254")) }

    fun parseLine(raw:String):SurveyPoint? {
        val line=raw.trim()
        if(line.isEmpty() || line.startsWith("#") || line.startsWith("//")) return null
        val p=line.split(Regex("[;\\t ]+")).filter{it.isNotBlank()}
        if(p.size<3) return null
        val name=p[0].trim()
        val y=num(p[1]) ?: return null
        val x=num(p[2]) ?: return null
        val z=p.getOrNull(3)?.let(::num)
        val code=if(z!=null) p.drop(4).joinToString(" ").ifBlank{null} else p.drop(3).joinToString(" ").ifBlank{null}
        return SurveyPoint(name,y,x,z,code)
    }
    private fun num(s:String):Double? {
        val v=s.trim()
        return when {
            v.count{it==','}==1 && !v.contains('.') -> v.replace(',','.').toDoubleOrNull()
            else -> v.replace(",","").toDoubleOrNull()
        }
    }
    fun export(points:List<SurveyPoint>):ByteArray {
        val body=points.joinToString("\r\n"){p->
            buildList {
                add(p.name); add("%.3f".format(java.util.Locale.US,p.y)); add("%.3f".format(java.util.Locale.US,p.x))
                p.z?.let{add("%.3f".format(java.util.Locale.US,it))}
                p.code?.takeIf{it.isNotBlank()}?.let{add(it)}
            }.joinToString("\t")
        }+"\r\n"
        return body.toByteArray(Charset.forName("windows-1254"))
    }
}
