package com.codeneedscoffee.steeped

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlin.concurrent.thread

/**
 * PLAN.md J5/J6 (Precise sync): decodes a clip of an audiobook to 16 kHz mono
 * PCM and feeds it, as it is decoded, to the on-device speech recogniser
 * through a pipe (no microphone is used; Android still wants RECORD_AUDIO for
 * the recogniser). The words heard so far are sent out as they arrive so the
 * caller can stop the listen the moment it is sure ([cancel]).
 *
 * Everything public runs on the main thread.
 */
class PreciseRecognizer(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())

    fun available(): Map<String, Any> = mapOf(
        "onDevice" to (android.os.Build.VERSION.SDK_INT >= 33 &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)),
        "service" to SpeechRecognizer.isRecognitionAvailable(context),
    )

    /** One listen. [finish] ends it from outside (cancel) or inside. */
    private class Session(val id: Int) {
        @Volatile var cancelled = false
        @Volatile var bytes = 0L
        var finish: ((String?) -> Unit)? = null
    }

    private var active: Session? = null

    /** Ends listen [id] now, reporting the words heard so far. */
    fun cancel(id: Int) {
        val s = active ?: return
        if (s.id != id) return
        s.cancelled = true
        s.finish?.invoke(null)
    }

    /**
     * Listens to [durMs] of the audio at [url] from [startMs]. [emit] gets
     * {id, text, audioMs} whenever the words so far change; [done] gets
     * {text, audioMs, recognizeMs, error} once, error null when it went fine.
     * Starting a listen ends any earlier one.
     */
    fun start(
        id: Int,
        url: String,
        startMs: Long,
        durMs: Long,
        lang: String,
        emit: (Map<String, Any?>) -> Unit,
        done: (Map<String, Any?>) -> Unit,
    ) {
        active?.let {
            it.cancelled = true
            it.finish?.invoke(null)
        }
        if (android.os.Build.VERSION.SDK_INT < 33 ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            done(mapOf("error" to "no on-device recogniser"))
            return
        }
        val session = Session(id)
        active = session
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        val pipe = ParcelFileDescriptor.createPipe()
        val t0 = System.currentTimeMillis()
        var firstChunkAt = -1L
        var firstPartialAt = -1L
        var readyAt = -1L
        val segments = mutableListOf<String>()
        var current = ""
        var finished = false

        fun heard() = (segments + listOf(current)).filter { it.isNotBlank() }.joinToString(" ")
        // The audio the recogniser has had, minus what is still in the pipe.
        fun audioMs() = maxOf(0L, session.bytes / 32 - 1500)
        fun finish(error: String?) {
            if (finished) return
            finished = true
            session.cancelled = true
            if (current.isNotBlank()) segments.add(current.trim())
            current = ""
            try {
                recognizer.destroy()
            } catch (_: Exception) {
            }
            try {
                pipe[0].close()
            } catch (_: Exception) {
            }
            if (active === session) active = null
            android.util.Log.i(
                "PreciseSpike",
                "timeline: ready=${readyAt}ms firstChunk=${firstChunkAt}ms firstPartial=${firstPartialAt}ms end=${System.currentTimeMillis() - t0}ms audio=${session.bytes / 32}ms",
            )
            done(
                mapOf(
                    "text" to segments.joinToString(" "),
                    "audioMs" to session.bytes / 32,
                    "recognizeMs" to System.currentTimeMillis() - t0,
                    "error" to error,
                ),
            )
        }
        session.finish = ::finish

        // The recogniser streams its words as partial results and only gives a
        // final result for the first utterance, so the transcript is built
        // from the partials: a partial that starts with a different word than
        // the one being built is a new utterance.
        fun commit() {
            if (current.isNotBlank()) segments.add(current.trim())
            current = ""
        }
        fun firstWord(t: String) = t.trim().substringBefore(' ').lowercase()
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {
                readyAt = System.currentTimeMillis() - t0
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onPartialResults(p: Bundle?) {
                val t = p?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: return
                if (finished) return
                if (firstPartialAt < 0) firstPartialAt = System.currentTimeMillis() - t0
                if (t.isBlank()) {
                    commit()
                } else {
                    if (current.isNotEmpty() && firstWord(t) != firstWord(current)) commit()
                    current = t
                }
                emit(mapOf("id" to id, "text" to heard(), "audioMs" to audioMs()))
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
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16000)
        }
        recognizer.startListening(intent)
        thread(name = "precise-feed") {
            val out = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
            try {
                decodeInto(url, startMs, durMs, session) { buf, n ->
                    if (firstChunkAt < 0) firstChunkAt = System.currentTimeMillis() - t0
                    out.write(buf, 0, n)
                    session.bytes += n
                }
            } catch (e: Exception) {
                if (!session.cancelled) main.post { finish("decode: ${e.message}") }
            } finally {
                try {
                    out.close() // end of audio: the recogniser finishes up
                } catch (_: Exception) {
                }
            }
        }
        // Safety net: a listen should never take minutes.
        main.postDelayed({ if (active === session) finish("timeout") }, 120_000)
    }

    // Opening a server file takes seconds, and Precise listens to the same file
    // several times, so the opened extractor is kept for a minute of idle.
    private var cachedUrl: String? = null
    private var cachedEx: MediaExtractor? = null
    private var cachedFormat: MediaFormat? = null
    private val dropCache = Runnable {
        cachedEx?.release()
        cachedEx = null
        cachedUrl = null
    }

    /**
     * Decodes the audio at [url] from [startMs] for [durMs] to 16 kHz mono
     * 16-bit PCM, handing it to [sink] in chunks as it is made, and stops when
     * [session] is cancelled.
     */
    @Synchronized
    private fun decodeInto(
        url: String,
        startMs: Long,
        durMs: Long,
        session: Session,
        sink: (ByteArray, Int) -> Unit,
    ) {
        val tA = System.currentTimeMillis()
        main.removeCallbacks(dropCache)
        if (cachedUrl != url) {
            main.post(dropCache) // release the old one on the main thread
            val opened = MediaExtractor()
            opened.setDataSource(url)
            var found = -1
            var f: MediaFormat? = null
            for (i in 0 until opened.trackCount) {
                val tf = opened.getTrackFormat(i)
                if (tf.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    found = i
                    f = tf
                    break
                }
            }
            if (found < 0 || f == null) {
                opened.release()
                throw IllegalStateException("no audio track")
            }
            opened.selectTrack(found)
            cachedEx = opened
            cachedFormat = f
            cachedUrl = url
        }
        val ex = cachedEx!!
        val format = cachedFormat!!
        val tB = System.currentTimeMillis()
        ex.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(format, null, null, 0)
        codec.start()
        val tC = System.currentTimeMillis()
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
        val chunk = ByteArray(16 * 1024)
        var filled = 0
        try {
            while (!outputDone && !session.cancelled) {
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
                                chunk[filled++] = (sh and 0xff).toByte()
                                chunk[filled++] = ((sh shr 8) and 0xff).toByte()
                                if (filled == chunk.size) {
                                    sink(chunk, filled)
                                    filled = 0
                                }
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
            if (filled > 0 && !session.cancelled) sink(chunk, filled)
        } finally {
            try {
                codec.stop()
                codec.release()
            } catch (_: Exception) {
            }
            main.postDelayed(dropCache, 60_000)
            android.util.Log.i(
                "PreciseSpike",
                "decode timings: open=${tB - tA}ms seek+codec=${tC - tB}ms decode=${System.currentTimeMillis() - tC}ms cancelled=${session.cancelled}",
            )
        }
    }
}
