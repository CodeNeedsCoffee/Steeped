package com.codeneedscoffee.steeped

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.os.Bundle
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

/**
 * PLAN.md J5/J6 (Precise sync): decodes a clip of an audiobook to 16 kHz mono
 * PCM and runs it through the on-device speech recogniser as a file (no
 * microphone is used; Android still wants RECORD_AUDIO for the recogniser).
 * Calls [done] on the main thread with a map: text, decodeMs, recognizeMs,
 * clipMs, error (null when fine).
 */
class PreciseRecognizer(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())

    fun available(): Map<String, Any> = mapOf(
        "onDevice" to (android.os.Build.VERSION.SDK_INT >= 33 &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)),
        "service" to SpeechRecognizer.isRecognitionAvailable(context),
    )

    /** Spike switches: feed from a file instead of a pipe; segmented session. */
    var useFile = false
    var segmented = false

    fun recognize(
        url: String,
        startMs: Long,
        durMs: Long,
        lang: String,
        done: (Map<String, Any?>) -> Unit,
    ) {
        thread(name = "precise-decode") {
            val t0 = System.currentTimeMillis()
            val pcm = try {
                decode(url, startMs, durMs)
            } catch (e: Exception) {
                main.post { done(mapOf("error" to "decode: ${e.message}")) }
                return@thread
            }
            val decodeMs = System.currentTimeMillis() - t0
            val clipMs = pcm.size / 2 / 16
            main.post { listen(pcm, lang, decodeMs, clipMs.toLong(), done) }
        }
    }

    /** Audio at [url] from [startMs] for [durMs] as 16 kHz mono 16-bit PCM. */
    private fun decode(url: String, startMs: Long, durMs: Long): ByteArray {
        val ex = MediaExtractor()
        ex.setDataSource(url)
        var track = -1
        var format: MediaFormat? = null
        for (i in 0 until ex.trackCount) {
            val f = ex.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                track = i
                format = f
                break
            }
        }
        if (track < 0 || format == null) throw IllegalStateException("no audio track")
        ex.selectTrack(track)
        ex.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(format, null, null, 0)
        codec.start()
        val out = ByteArrayOutputStream()
        val info = MediaCodec.BufferInfo()
        var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val endUs = (startMs + durMs) * 1000
        var inputDone = false
        var outputDone = false
        // Linear resampling state carried across buffers.
        var pos = 0.0
        var prev = 0.0
        var havePrev = false
        while (!outputDone) {
            if (!inputDone) {
                val i = codec.dequeueInputBuffer(10_000)
                if (i >= 0) {
                    val buf = codec.getInputBuffer(i)!!
                    val n = ex.readSampleData(buf, 0)
                    if (n < 0 || ex.sampleTime > endUs) {
                        codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                        ex.advance()
                    }
                }
            }
            val o = codec.dequeueOutputBuffer(info, 10_000)
            when {
                o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val f = codec.outputFormat
                    rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
                o >= 0 -> {
                    val buf = codec.getOutputBuffer(o)!!
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    val shorts = buf.order(java.nio.ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                    val frames = shorts.remaining() / channels
                    val step = rate / 16000.0
                    for (fi in 0 until frames) {
                        var sum = 0
                        for (c in 0 until channels) sum += shorts.get(fi * channels + c)
                        val s = sum / channels.toDouble()
                        // Emit a 16 kHz sample each time the read position
                        // crosses a source sample.
                        while (pos < 1.0) {
                            val v = if (havePrev) prev + (s - prev) * pos else s
                            val sh = v.toInt().coerceIn(-32768, 32767)
                            out.write(sh and 0xff)
                            out.write((sh shr 8) and 0xff)
                            pos += step
                        }
                        pos -= 1.0
                        prev = s
                        havePrev = true
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
            }
        }
        codec.stop()
        codec.release()
        ex.release()
        return out.toByteArray()
    }

    private fun listen(
        pcm: ByteArray,
        lang: String,
        decodeMs: Long,
        clipMs: Long,
        done: (Map<String, Any?>) -> Unit,
    ) {
        if (android.os.Build.VERSION.SDK_INT < 33 ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            done(mapOf("error" to "no on-device recogniser"))
            return
        }
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        val pipe = if (useFile) null else ParcelFileDescriptor.createPipe()
        val source: ParcelFileDescriptor = if (pipe == null) {
            val f = java.io.File(context.cacheDir, "precise_clip.pcm")
            f.writeBytes(pcm)
            ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY)
        } else {
            pipe[0]
        }
        val t0 = System.currentTimeMillis()
        val segments = mutableListOf<String>()
        var finished = false
        fun finish(error: String?) {
            if (finished) return
            finished = true
            recognizer.destroy()
            done(
                mapOf(
                    "text" to segments.joinToString(" "),
                    "decodeMs" to decodeMs,
                    "recognizeMs" to System.currentTimeMillis() - t0,
                    "clipMs" to clipMs,
                    "error" to error,
                ),
            )
        }
        // The recogniser streams its words as partial results and only gives a
        // final result for the first utterance, so the transcript is built
        // from the partials: a partial that starts with a different word than
        // the one being built is a new utterance.
        var current = ""
        fun commit() {
            if (current.isNotBlank()) segments.add(current.trim())
            current = ""
        }
        fun firstWord(t: String) = t.trim().substringBefore(' ').lowercase()
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onPartialResults(p: Bundle?) {
                val t = p?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: return
                if (t.isBlank()) {
                    commit()
                } else {
                    if (current.isNotEmpty() && firstWord(t) != firstWord(current)) commit()
                    current = t
                }
            }
            override fun onError(error: Int) {
                commit()
                finish("error $error")
            }
            override fun onResults(r: Bundle?) {
                r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                    ?.let { if (it.isNotBlank()) current = it }
                commit()
                finish(null)
            }
            override fun onSegmentResults(r: Bundle) {}
            override fun onEndOfSegmentedSession() {
                commit()
                finish(null)
            }
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            if (segmented) putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, true)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, source)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16000)
        }
        recognizer.startListening(intent)
        if (pipe != null) thread(name = "precise-feed") {
            try {
                ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { it.write(pcm) }
            } catch (_: Exception) {
            }
        }
        // Safety net: recognition of a short clip should not take minutes.
        main.postDelayed({ finish("timeout") }, 180_000)
    }
}
