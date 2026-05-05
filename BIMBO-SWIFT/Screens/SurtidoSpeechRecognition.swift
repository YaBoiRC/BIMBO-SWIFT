import AVFoundation
import Observation
import Speech

struct ParsedValidationSpeechInput {
    let categoryName: String?
    let currentPieces: Int?
    let currentWeightGrams: Int?
    let spoiledPieces: Int?
    let targetTotal: Int?
    let purchaseQuantity: Int?
}

@Observable
final class ValidationSpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording() async {
        errorMessage = nil

        let authorizationStatus = await requestAuthorization()
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition permission is required."
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available right now."
            return
        }

        stopRecording()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            transcript = ""

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.stopRecording()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stopRecording()
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopRecording()
        transcript = ""
        errorMessage = nil
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func parse(
        transcript: String,
        categories: [String]
    ) -> ParsedValidationSpeechInput {
        let normalizedTranscript = normalize(transcript)
        let fieldBoundary = #"(?=,|$|\s+(?:piezas actuales|actual(?:es)?(?: en tienda)?|producto actual(?: en tienda)?|cantidad actual|peso(?: actual| total)?(?: en tienda)?|tengo(?: en tienda)?|hay(?: en tienda)?|echado a perder|merma|perdido|quiere comprar|comprar|objetivo del cliente|quiere tener(?: en total)?|tener total)\b)"#
        let detectedCategory = categories.first { category in
            normalizedTranscript.contains(normalize(category))
        }

        let currentPieces = extractFirstInteger(
            in: normalizedTranscript,
            patterns: [
                #"piezas actuales\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"actual(?:es)?(?: en tienda)?\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"producto actual(?: en tienda)?\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"cantidad actual\s+([a-z0-9\s]+?)"# + fieldBoundary
            ]
        )

        let currentWeightGrams =
            extractFirstInteger(
                in: normalizedTranscript,
                patterns: [
                    #"peso(?: actual| total)?(?: en tienda)?(?: de)?\s+([a-z0-9\s]+?)\s+(?:gramos?|gr|g)"# + fieldBoundary,
                    #"producto actual(?: en tienda)?(?: de)?\s+([a-z0-9\s]+?)\s+(?:gramos?|gr|g)"# + fieldBoundary,
                    #"actual(?:es)?(?: en tienda)?(?: de)?\s+([a-z0-9\s]+?)\s+(?:gramos?|gr|g)"# + fieldBoundary,
                    #"tengo(?: en tienda)?\s+([a-z0-9\s]+?)\s+(?:gramos?|gr|g)"# + fieldBoundary,
                    #"hay(?: en tienda)?\s+([a-z0-9\s]+?)\s+(?:gramos?|gr|g)"# + fieldBoundary
                ]
            ) ?? extractFirstWeightInteger(in: normalizedTranscript)

        let spoiledPieces = extractFirstInteger(
            in: normalizedTranscript,
            patterns: [
                #"echado a perder\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"merma\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"perdido\s+([a-z0-9\s]+?)"# + fieldBoundary
            ]
        )

        let purchaseQuantity = extractFirstInteger(
            in: normalizedTranscript,
            patterns: [
                #"quiere comprar\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"comprar\s+([a-z0-9\s]+?)"# + fieldBoundary
            ]
        )

        let targetTotal = extractFirstInteger(
            in: normalizedTranscript,
            patterns: [
                #"objetivo del cliente\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"quiere tener(?: en total)?\s+([a-z0-9\s]+?)"# + fieldBoundary,
                #"tener total\s+([a-z0-9\s]+?)"# + fieldBoundary,
            ]
        )

        return ParsedValidationSpeechInput(
            categoryName: detectedCategory,
            currentPieces: currentPieces,
            currentWeightGrams: currentWeightGrams,
            spoiledPieces: spoiledPieces,
            targetTotal: targetTotal,
            purchaseQuantity: purchaseQuantity
        )
    }

    private static func extractFirstInteger(in text: String, patterns: [String]) -> Int? {
        for pattern in patterns {
            if let value = firstMatch(in: text, pattern: pattern) {
                if let parsed = parseSpanishNumber(value) {
                    return parsed
                }
            }
        }
        return nil
    }

    private static func extractFirstWeightInteger(in text: String) -> Int? {
        let unitsPattern = #"\b([a-z0-9]+(?:\s+[a-z0-9]+){0,4})\s*(?:gramos?|gr|g)\b"#
        return extractFirstInteger(in: text, patterns: [unitsPattern])
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[captureRange])
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_MX"))
            .lowercased()
    }

    private static func parseSpanishNumber(_ rawValue: String) -> Int? {
        let cleaned = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " y ", with: " ")

        if let directInt = Int(cleaned.filter(\.isNumber)), cleaned.contains(where: \.isNumber) {
            return directInt
        }

        let units: [String: Int] = [
            "cero": 0,
            "un": 1, "uno": 1, "una": 1,
            "dos": 2,
            "tres": 3,
            "cuatro": 4,
            "cinco": 5,
            "seis": 6,
            "siete": 7,
            "ocho": 8,
            "nueve": 9,
            "diez": 10,
            "once": 11,
            "doce": 12,
            "trece": 13,
            "catorce": 14,
            "quince": 15,
            "dieciseis": 16,
            "diecisiete": 17,
            "dieciocho": 18,
            "diecinueve": 19,
            "veinte": 20,
            "veintiuno": 21,
            "veintidos": 22,
            "veintitres": 23,
            "veinticuatro": 24,
            "veinticinco": 25,
            "veintiseis": 26,
            "veintisiete": 27,
            "veintiocho": 28,
            "veintinueve": 29
        ]

        let tens: [String: Int] = [
            "treinta": 30,
            "cuarenta": 40,
            "cincuenta": 50,
            "sesenta": 60,
            "setenta": 70,
            "ochenta": 80,
            "noventa": 90,
            "cien": 100
        ]

        if let single = units[cleaned] ?? tens[cleaned] {
            return single
        }

        let words = cleaned.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }

        var total = 0
        for word in words {
            if let value = units[word] ?? tens[word] {
                total += value
            }
        }

        return total > 0 ? total : nil
    }
}
