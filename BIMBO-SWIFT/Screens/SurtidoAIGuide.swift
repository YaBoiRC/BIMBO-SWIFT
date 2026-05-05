import AVFoundation
import FoundationModels
import SwiftUI

struct UnloadGuideGenerator {
    private let model = SystemLanguageModel.default

    func generateGuide(
        clientName: String,
        assignments: [ClientTrayAssignment],
        recommendation: UnloadRecommendation
    ) async throws -> UnloadGuideResult {
        guard model.availability == .available else {
            return Self.fallbackGuide(
                clientName: clientName,
                assignments: assignments,
                recommendation: recommendation,
                message: availabilityMessage
            )
        }

        let session = LanguageModelSession(instructions: """
        Genera instrucciones operativas para desembarque en tienda.
        Responde solo con lineas que empiecen con STEP: o STOPPER:.
        Cada linea debe ser corta, accionable y en espanol.
        No generes pasos genericos como entrar a tienda, salir, saludar o despedirse.
        Debes incluir obligatoriamente estos momentos:
        1. Solicita el numero de compra.
        2. Valida que el pedido fisico coincida con el pedido esperado.
        3. Verifica cantidad de producto en tienda.
        4. Verifica producto echado a perder.
        5. Baja la mercancia con detalle exacto de bandejas, anaqueles y slots.
        Incluye STOPPER solo cuando haya riesgo de error operativo, caducidad o diferencia de pedido.
        """)

        let assignmentText = assignments.map { assignment in
            "\(assignment.trayName) | \(assignment.productName) | \(assignment.wallName) | \(assignment.shelfName) | slots \(assignment.slotNumbers.map(String.init).joined(separator: ", ")) | caducidad \(assignment.expirationLabel)"
        }
        .joined(separator: "\n")

        let prompt = """
        Cliente: \(clientName)
        Productos a descargar: \(recommendation.finalUnload)
        Merma a retirar: \(recommendation.spoiled)
        Bandejas:
        \(assignmentText)

        Genera entre 6 y 10 lineas totales.
        En el paso de bajar mercancia menciona explicitamente numeros de bandeja, anaquel y slots.
        """

        let response = try await session.respond(to: prompt)
        let directives = normalizedDirectives(
            from: parseDirectives(from: response.content),
            clientName: clientName,
            assignments: assignments,
            recommendation: recommendation
        )

        if directives.isEmpty {
            return Self.fallbackGuide(
                clientName: clientName,
                assignments: assignments,
                recommendation: recommendation,
                message: "La AI no devolvio un formato util. Se muestra una guia local."
            )
        }

        return UnloadGuideResult(
            directives: directives,
            statusMessage: "Guia generada con Apple Intelligence."
        )
    }

    private func normalizedDirectives(
        from generated: [UnloadDirective],
        clientName: String,
        assignments: [ClientTrayAssignment],
        recommendation: UnloadRecommendation
    ) -> [UnloadDirective] {
        let unloadSteps = Self.unloadAssignmentDirectives(from: assignments)
        guard !unloadSteps.isEmpty else {
            return Self.fallbackGuide(
                clientName: clientName,
                assignments: assignments,
                recommendation: recommendation,
                message: nil
            ).directives
        }

        let generatedStoppers = generated.filter { $0.kind == .stopper }
        var directives: [UnloadDirective] = [
            UnloadDirective(
                kind: .step,
                message: "Solicita el numero de compra del cliente \(clientName) y confirma que corresponda a esta visita.",
                trayName: nil
            ),
            UnloadDirective(
                kind: .step,
                message: "Valida que el pedido esperado coincida con \(recommendation.finalUnload) productos previstos antes de bajar mercancia.",
                trayName: nil
            ),
            UnloadDirective(
                kind: .step,
                message: "Verifica la cantidad de productos en la tienda usando la validacion capturada por categoria.",
                trayName: nil
            ),
            UnloadDirective(
                kind: .step,
                message: "Verifica la cantidad de productos echados a perder y separalos para retiro antes del acomodo.",
                trayName: nil
            )
        ]

        if let firstStopper = generatedStoppers.first {
            directives.append(firstStopper)
        } else {
            directives.append(
                UnloadDirective(
                    kind: .stopper,
                    message: "Deten el proceso si el numero de compra, el pedido esperado o la merma no coinciden con la validacion de tienda.",
                    trayName: nil
                )
            )
        }

        directives += unloadSteps

        if let caducityStopper = generatedStoppers.dropFirst().first {
            directives.append(caducityStopper)
        } else if let firstAssignment = assignments.first {
            directives.append(
                UnloadDirective(
                    kind: .stopper,
                    message: "No mezcles bandejas con distinta caducidad; verifica \(firstAssignment.expirationLabel) antes de bajar la siguiente bandeja.",
                    trayName: nil
                )
            )
        }

        return directives
    }

    private func parseDirectives(from text: String) -> [UnloadDirective] {
        text
            .split(separator: "\n")
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if line.hasPrefix("STEP:") {
                    let message = line.replacingOccurrences(of: "STEP:", with: "").trimmingCharacters(in: .whitespaces)
                    return UnloadDirective(kind: .step, message: message, trayName: nil)
                }

                if line.hasPrefix("STOPPER:") {
                    let message = line.replacingOccurrences(of: "STOPPER:", with: "").trimmingCharacters(in: .whitespaces)
                    return UnloadDirective(kind: .stopper, message: message, trayName: nil)
                }

                return nil
            }
    }

    private var availabilityMessage: String? {
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Este dispositivo no es compatible con Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence esta desactivada."
        case .unavailable(.modelNotReady):
            return "El modelo generativo aun no esta listo."
        case .unavailable:
            return "La AI generativa no esta disponible en este momento."
        }
    }

    static func fallbackGuide(
        clientName: String,
        assignments: [ClientTrayAssignment],
        recommendation: UnloadRecommendation,
        message: String?
    ) -> UnloadGuideResult {
        let sortedAssignments = assignments.sorted { lhs, rhs in
            if lhs.wallName != rhs.wallName { return lhs.wallName < rhs.wallName }
            if lhs.shelfName != rhs.shelfName { return lhs.shelfName < rhs.shelfName }
            return lhs.trayName < rhs.trayName
        }

        var directives: [UnloadDirective] = [
            UnloadDirective(kind: .step, message: "Solicita el numero de compra del cliente \(clientName) y confirma que corresponda a esta visita.", trayName: nil),
            UnloadDirective(kind: .step, message: "Valida que el pedido esperado coincida con \(recommendation.finalUnload) productos previstos antes de bajar mercancia.", trayName: nil),
            UnloadDirective(kind: .step, message: "Verifica la cantidad de productos en la tienda usando la validacion capturada por categoria.", trayName: nil),
            UnloadDirective(kind: .step, message: "Verifica la cantidad de productos echados a perder y separalos para retiro antes del acomodo.", trayName: nil),
            UnloadDirective(kind: .stopper, message: "Deten el proceso si el numero de compra o la merma no coincide con la validacion de tienda.", trayName: nil)
        ]

        directives += unloadAssignmentDirectives(from: sortedAssignments)

        directives.append(
            UnloadDirective(
                kind: .stopper,
                message: "No mezcles bandejas con distinta caducidad; verifica \(sortedAssignments.first?.expirationLabel ?? "caducidad") antes de bajar la siguiente bandeja.",
                trayName: nil
            )
        )

        return UnloadGuideResult(directives: directives, statusMessage: message)
    }

    private static func unloadAssignmentDirectives(from assignments: [ClientTrayAssignment]) -> [UnloadDirective] {
        assignments
            .sorted { lhs, rhs in
                if lhs.wallName != rhs.wallName { return lhs.wallName < rhs.wallName }
                if lhs.shelfName != rhs.shelfName { return lhs.shelfName < rhs.shelfName }
                return lhs.trayName < rhs.trayName
            }
            .prefix(6)
            .map { assignment in
                UnloadDirective(
                    kind: .step,
                    message: "Baja la mercancia de \(assignment.trayName) en \(assignment.shelfName), \(assignment.wallName), para \(assignment.productName); descarga los slots \(assignment.slotNumbers.map(String.init).joined(separator: ", ")).",
                    trayName: assignment.trayName
                )
            }
    }
}

@MainActor
final class UnloadGuideNarrator: NSObject {
    static let shared = UnloadGuideNarrator()

    private let synthesizer = AVSpeechSynthesizer()
    private var finishHandler: (() -> Void)?
    private var narrationTask: Task<Void, Never>?

    func speak(text: String, onFinish: @escaping () -> Void) {
        stop()
        finishHandler = onFinish

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
        narrationTask = Task { @MainActor in
            let estimatedSeconds = max(5.0, Double(text.count) / 11.0)
            try? await Task.sleep(for: .seconds(estimatedSeconds))
            guard !Task.isCancelled else { return }
            self.finishHandler?()
            self.finishHandler = nil
            self.narrationTask = nil
        }
    }

    func stop() {
        narrationTask?.cancel()
        narrationTask = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishHandler = nil
    }
}
