import AVFoundation
import Flutter
import Foundation
import Speech

/// Precise on iOS: answers the `steeped/precise` channel the same way the
/// Android plugin does (`available`, `recognize` with streaming `partial`
/// calls, `cancel`), plus `prepare` to install the speech model.
///
/// Recognition runs on the phone with Apple's SpeechAnalyzer (iOS 26+) over a
/// downloaded audio file; no microphone is opened and nothing leaves the
/// device. Below iOS 26 `available` answers false and the rest never runs.
final class PreciseRecognizer {
  private let channel: FlutterMethodChannel
  private var task: Task<Void, Never>?
  private var activeId = -1

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "steeped/precise", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard #available(iOS 26.0, *) else {
      switch call.method {
      case "available": result(["onDevice": false, "ready": false])
      case "cancel": result(nil)
      default: result(["error": "needs iOS 26"])
      }
      return
    }
    switch call.method {
    case "available":
      Task { result(await self.available(lang: args["lang"] as? String ?? "en-US")) }
    case "prepare":
      Task { result(await self.prepare(lang: args["lang"] as? String ?? "en-US")) }
    case "recognize":
      let id = (args["id"] as? NSNumber)?.intValue ?? 0
      task?.cancel()
      activeId = id
      task = Task {
        let out = await self.listen(
          id: id,
          path: args["path"] as? String ?? "",
          startMs: (args["startMs"] as? NSNumber)?.intValue ?? 0,
          durMs: (args["durMs"] as? NSNumber)?.intValue ?? 30000,
          lang: args["lang"] as? String ?? "en-US")
        result(out)
      }
    case "cancel":
      if (args["id"] as? NSNumber)?.intValue == activeId { task?.cancel() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: availability and model

  /// {onDevice: this phone can run it, ready: the language model is installed}.
  @available(iOS 26.0, *)
  private func available(lang: String) async -> [String: Any] {
    guard SpeechTranscriber.isAvailable,
      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: lang))
    else { return ["onDevice": false, "ready": false] }
    let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    let status = await AssetInventory.status(forModules: [transcriber])
    return ["onDevice": true, "ready": status == .installed]
  }

  /// Installs and reserves the language model, sending `prepareProgress`
  /// {fraction} while it downloads. Returns {ready} or {error}.
  @available(iOS 26.0, *)
  private func prepare(lang: String) async -> [String: Any] {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: lang))
    else { return ["error": "unsupported locale"] }
    let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
        let poll = Task {
          while !Task.isCancelled {
            let fraction = request.progress.fractionCompleted
            await MainActor.run {
              self.channel.invokeMethod("prepareProgress", arguments: ["fraction": fraction])
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
          }
        }
        defer { poll.cancel() }
        try await request.downloadAndInstall()
      }
      // A full set of reserved locales makes this throw; the model is
      // installed either way, so it is not fatal.
      try? await AssetInventory.reserve(locale: locale)
      return ["ready": true]
    } catch {
      return ["error": "\(error)"]
    }
  }

  // MARK: one listen

  /// Listens to `durMs` of the file at `path` from `startMs`. Sends
  /// `partial` {id, text, audioMs} as the words so far change and returns
  /// {text, audioMs, error}. A cancel ends it early and returns what was heard.
  @available(iOS 26.0, *)
  private func listen(id: Int, path: String, startMs: Int, durMs: Int, lang: String) async -> [String: Any] {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: lang))
    else { return ["error": "unsupported locale"] }
    let transcriber = SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults],
      attributeOptions: [.audioTimeRange])
    let analyzer = SpeechAnalyzer(
      modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .lingering))
    guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    else { return ["error": "no audio format"] }

    // Words heard: segments already final, plus the one still changing.
    var finalText = ""
    var volatileText = ""
    var audioMs = 0
    func heard() -> String { (finalText + " " + volatileText).trimmingCharacters(in: .whitespaces) }

    let reader = Task {
      do {
        for try await r in transcriber.results {
          let text = String(r.text.characters)
          if r.isFinal {
            finalText += (finalText.isEmpty ? "" : " ") + text
            volatileText = ""
          } else {
            volatileText = text
          }
          for run in r.text.runs {
            if let range = run.audioTimeRange {
              audioMs = max(audioMs, Int(range.end.seconds * 1000))
            }
          }
          let words = heard()
          let ms = audioMs
          await MainActor.run {
            self.channel.invokeMethod("partial", arguments: ["id": id, "text": words, "audioMs": ms])
          }
        }
      } catch {}
    }

    var error: String?
    do {
      let (inputs, continuation) = AsyncStream<AnalyzerInput>.makeStream()
      try await analyzer.start(inputSequence: inputs)
      try feed(path: path, startMs: startMs, durMs: durMs, format: format, into: continuation)
      continuation.finish()
      if Task.isCancelled {
        await analyzer.cancelAndFinishNow()
      } else {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
      }
    } catch {
      await analyzer.cancelAndFinishNow()
      if !Task.isCancelled { error = "\(error)" }
    }
    await reader.value
    var out: [String: Any] = ["text": heard(), "audioMs": audioMs]
    if let error { out["error"] = error }
    return out
  }

  /// Decodes the clip and yields it in the analyser's format, stopping early
  /// when this task is cancelled.
  @available(iOS 26.0, *)
  private func feed(
    path: String, startMs: Int, durMs: Int, format: AVAudioFormat,
    into continuation: AsyncStream<AnalyzerInput>.Continuation
  ) throws {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let rate = file.processingFormat.sampleRate
    file.framePosition = AVAudioFramePosition(Double(startMs) / 1000 * rate)
    var remaining = AVAudioFrameCount(Double(durMs) / 1000 * rate)
    guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else {
      throw NSError(domain: "Precise", code: 1, userInfo: [NSLocalizedDescriptionKey: "no converter"])
    }
    let chunk: AVAudioFrameCount = 16384
    while remaining > 0 && !Task.isCancelled {
      let n = min(chunk, remaining)
      guard
        let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: n)
      else { break }
      try file.read(into: input, frameCount: n)
      if input.frameLength == 0 { break }
      remaining -= input.frameLength
      let capacity = AVAudioFrameCount(Double(input.frameLength) * format.sampleRate / rate) + 32
      guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { break }
      var supplied = false
      var convertError: NSError?
      converter.convert(to: output, error: &convertError) { _, status in
        if supplied {
          status.pointee = .noDataNow
          return nil
        }
        supplied = true
        status.pointee = .haveData
        return input
      }
      if let convertError { throw convertError }
      if output.frameLength > 0 { continuation.yield(AnalyzerInput(buffer: output)) }
    }
  }
}
