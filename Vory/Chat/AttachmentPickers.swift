import AVFoundation
import Speech
import SwiftUI
import UIKit
import VoryCore

/// System camera capture.
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (Data, String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage, let data = img.jpegData(compressionQuality: 0.9) {
                parent.onImage(data, "camera-\(Int(Date().timeIntervalSince1970)).jpg")
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Voice memo recorder (AAC .m4a).
struct AudioRecorderSheet: View {
    var onFinished: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recorder: AVAudioRecorder?
    @State private var recording = false
    @State private var elapsed: TimeInterval = 0
    @State private var url: URL?
    @State private var error: String?
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: recording ? "waveform.circle.fill" : "waveform.circle").font(.system(size: 72)).foregroundStyle(recording ? .red : .secondary)
                    .symbolEffect(.variableColor.iterative, isActive: recording)
                Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond))).font(.largeTitle.monospacedDigit())
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                HStack(spacing: 16) {
                    Button(recording ? "Stop" : "Record") { recording ? stop() : start() }.buttonStyle(.glassProminent).tint(recording ? .red : .accentColor)
                    if let url, !recording { Button("Attach") { onFinished(url); dismiss() }.buttonStyle(.glass) }
                }
            }
            .padding()
            .navigationTitle("Record Audio")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { stop(); dismiss() } } }
        }
        .presentationDetents([.medium])
    }

    private func start() {
        Task {
            guard await AVAudioApplication.requestRecordPermission() else { error = "Microphone access denied."; return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("memo-\(Int(Date().timeIntervalSince1970)).m4a")
                let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
                let r = try AVAudioRecorder(url: u, settings: settings)
                r.record()
                recorder = r; url = u; recording = true; elapsed = 0
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in Task { @MainActor in elapsed = r.currentTime } }
            } catch { self.error = error.localizedDescription }
        }
    }

    private func stop() {
        recorder?.stop(); recorder = nil; recording = false
        timer?.invalidate(); timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Owns the audio engine and the recognition request, deliberately outside any actor: AVFAudio and
/// Speech call back on their own queues, and a closure formed inside a @MainActor method inherits
/// that isolation and traps at runtime — both TestFlight crashes on the mic button were exactly that.
private final class DictationPipeline: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    func start(recognizer: SFSpeechRecognizer, onUpdate: @escaping @Sendable (String?, Bool) -> Void) throws {
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        let req = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
        engine.prepare()
        try engine.start()
        task = recognizer.recognitionTask(with: req) { result, err in
            onUpdate(result?.bestTranscription.formattedString, err != nil)
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task?.finish()
        task = nil
    }
}

/// On-device speech recognition for hold-to-talk.
@MainActor
@Observable
final class DictationController {
    private var pipeline: DictationPipeline?
    var transcript = ""
    var isListening = false
    var error: String?

    /// TCC invokes the completion on a private queue; built outside any actor for the same reason
    /// as `DictationPipeline`.
    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in c.resume(returning: status) }
        }
    }

    func start() {
        Task {
            let auth = await Self.requestSpeechAuthorization()
            guard auth == .authorized else { error = "Speech recognition not authorized."; return }
            guard await AVAudioApplication.requestRecordPermission() else { error = "Microphone access denied."; return }
            guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(), recognizer.isAvailable else {
                error = "Speech recognizer unavailable."; return
            }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                transcript = ""
                let pipe = DictationPipeline()
                pipeline = pipe
                try pipe.start(recognizer: recognizer) { [weak self] text, failed in
                    Task { @MainActor in
                        guard let self else { return }
                        if let text { self.transcript = text }
                        if failed { self.stop() }
                    }
                }
                isListening = true
            } catch { self.error = error.localizedDescription }
        }
    }

    func stop() {
        pipeline?.stop()
        pipeline = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct HoldToTalkButton: View {
    var dictation: DictationController
    var onTranscript: (String) -> Void

    var body: some View {
        // Sits inside the composer capsule now, so it is a bare glyph in the same 28pt slot as Send.
        Image(systemName: dictation.isListening ? "mic.fill" : "mic")
            .font(.body.weight(.medium))
            .frame(width: 28, height: 28)
            .foregroundStyle(dictation.isListening ? .red : .secondary)
            .contentShape(.circle)
            .accessibilityLabel("Hold to talk")
            .accessibilityHint("Press and hold to dictate with on-device speech recognition")
            .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 60) {
                // released
            } onPressingChanged: { pressing in
                if pressing { dictation.start() }
                else if dictation.isListening {
                    dictation.stop()
                    let t = dictation.transcript
                    if !t.isEmpty { onTranscript(t) }
                }
            }
    }
}
