import AVFoundation
import Speech

@MainActor
final class AudioService: ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var rawAudioBuffers: [AVAudioPCMBuffer] = []
    
    var onTextRecognized: ((String) -> Void)?
    var onAudioChunk: ((Data) -> Void)?
    
    func requestPermission() async -> Bool {
        // Request microphone permission
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard micGranted else { return false }
        
        // Request Speech Recognition permission
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        return speechGranted
    }
    
    func startListening() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Initialize Speech Recognition
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
        guard speechRecognizer?.isAvailable == true else {
            throw NSError(domain: "AudioService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "AudioService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        rawAudioBuffers = []
        recognizedText = ""
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            recognitionRequest.append(buffer)
            
            if let bufferCopy = self.copyBuffer(buffer) {
                self.rawAudioBuffers.append(bufferCopy)
            }
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.recognizedText = text
                    print("🎤 Recognized: \(text)")
                    self.onTextRecognized?(text)
                }
            }
            
            if error != nil {
                print("❌ Speech recognition error: \(error?.localizedDescription ?? "Unknown")")
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
    }
    
    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let format = buffer.format
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else { return nil }
        
        copy.frameLength = buffer.frameLength
        
        guard let srcData = buffer.floatChannelData,
              let dstData = copy.floatChannelData else { return nil }
        
        for ch in 0..<Int(format.channelCount) {
            memcpy(dstData[ch], srcData[ch], Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }
        
        return copy
    }
    
    private func convertBuffersToWAV(_ buffers: [AVAudioPCMBuffer]) -> Data {
        guard !buffers.isEmpty else { return Data() }
        
        let format = buffers[0].format
        let sampleRate = Int(format.sampleRate)
        let channelCount = Int(format.channelCount)
        
        var allPCMData = Data()
        
        for buffer in buffers {
            guard let channelData = buffer.floatChannelData else { continue }
            let channelDataValue = channelData.pointee
            let frameLengthInt = Int(buffer.frameLength)
            
            for i in 0..<frameLengthInt {
                let sample = channelDataValue[i]
                let pcmSample: Int16 = Int16(max(-32768, min(32767, Int32(sample * 32767))))
                let bytes = pcmSample.littleEndian
                allPCMData.append(UInt8(bytes & 0xFF))
                allPCMData.append(UInt8((bytes >> 8) & 0xFF))
            }
        }
        
        var wavData = Data()
        
        // RIFF Header
        wavData.append(contentsOf: [UInt8(ascii: "R"), UInt8(ascii: "I"), UInt8(ascii: "F"), UInt8(ascii: "F")])
        
        let fileSize = UInt32(36 + allPCMData.count)
        let fileSizeBytes = fileSize.littleEndian
        wavData.append(UInt8(fileSizeBytes & 0xFF))
        wavData.append(UInt8((fileSizeBytes >> 8) & 0xFF))
        wavData.append(UInt8((fileSizeBytes >> 16) & 0xFF))
        wavData.append(UInt8((fileSizeBytes >> 24) & 0xFF))
        
        wavData.append(contentsOf: [UInt8(ascii: "W"), UInt8(ascii: "A"), UInt8(ascii: "V"), UInt8(ascii: "E")])
        
        // fmt subchunk
        wavData.append(contentsOf: [UInt8(ascii: "f"), UInt8(ascii: "m"), UInt8(ascii: "t"), UInt8(ascii: " ")])
        wavData.append(contentsOf: [16, 0, 0, 0])
        wavData.append(contentsOf: [1, 0])
        
        let chCount = UInt16(channelCount).littleEndian
        wavData.append(UInt8(chCount & 0xFF))
        wavData.append(UInt8((chCount >> 8) & 0xFF))
        
        let sRate = UInt32(sampleRate).littleEndian
        wavData.append(UInt8(sRate & 0xFF))
        wavData.append(UInt8((sRate >> 8) & 0xFF))
        wavData.append(UInt8((sRate >> 16) & 0xFF))
        wavData.append(UInt8((sRate >> 24) & 0xFF))
        
        let byteRate = UInt32(sampleRate * channelCount * 2)
        let byteRateBytes = byteRate.littleEndian
        wavData.append(UInt8(byteRateBytes & 0xFF))
        wavData.append(UInt8((byteRateBytes >> 8) & 0xFF))
        wavData.append(UInt8((byteRateBytes >> 16) & 0xFF))
        wavData.append(UInt8((byteRateBytes >> 24) & 0xFF))
        
        let blockAlign = UInt16(channelCount * 2)
        let blockBytes = blockAlign.littleEndian
        wavData.append(UInt8(blockBytes & 0xFF))
        wavData.append(UInt8((blockBytes >> 8) & 0xFF))
        
        wavData.append(contentsOf: [16, 0])
        
        // Data subchunk
        wavData.append(contentsOf: [UInt8(ascii: "d"), UInt8(ascii: "a"), UInt8(ascii: "t"), UInt8(ascii: "a")])
        
        let dataSize = UInt32(allPCMData.count).littleEndian
        wavData.append(UInt8(dataSize & 0xFF))
        wavData.append(UInt8((dataSize >> 8) & 0xFF))
        wavData.append(UInt8((dataSize >> 16) & 0xFF))
        wavData.append(UInt8((dataSize >> 24) & 0xFF))
        
        wavData.append(allPCMData)
        
        return wavData
    }
}
