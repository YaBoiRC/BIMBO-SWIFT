import AVFoundation
import FoundationModels
import SwiftUI


struct LoadGuideTrayInput {
    let clientName: String
    let trayName: String
    let wallName: String
    let shelfName: String
    let productName: String
    let slotNumbers: [Int]
    let quantity: Int
    let weightKg: Double
    let productionDate: String
}

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
        Para la pared usa flechas: izquierda = ←, derecha = →, frente = ↑.
        Para anaquel y bandeja usa siempre numeros, por ejemplo Anaquel 2 y Bandeja 4.
        Cuando menciones bandeja, agrega tambien el rango de indices de esa bandeja, por ejemplo Bandeja 4 (1-10) o Bandeja 4 (4-9).
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
        En el paso de bajar mercancia menciona explicitamente flecha de pared, numero de anaquel, numero de bandeja, rango de indices de la bandeja y slots.
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
                trayName: nil,
                badges: []
            ),
            UnloadDirective(
                kind: .step,
                message: "Valida que el pedido esperado coincida con \(recommendation.finalUnload) productos previstos antes de bajar mercancia.",
                trayName: nil,
                badges: []
            ),
            UnloadDirective(
                kind: .step,
                message: "Verifica la cantidad de productos en la tienda usando la validacion capturada por categoria.",
                trayName: nil,
                badges: []
            ),
            UnloadDirective(
                kind: .step,
                message: "Verifica la cantidad de productos echados a perder y separalos para retiro antes del acomodo.",
                trayName: nil,
                badges: []
            )
        ]

        if let firstStopper = generatedStoppers.first {
            directives.append(firstStopper)
        } else {
            directives.append(
                UnloadDirective(
                    kind: .stopper,
                    message: "Deten el proceso si el numero de compra, el pedido esperado o la merma no coinciden con la validacion de tienda.",
                    trayName: nil,
                    badges: []
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
                    trayName: nil,
                    badges: []
                )
            )
        }

        return directives.map { formattedDirective($0, assignments: assignments) }
    }

    private func parseDirectives(from text: String) -> [UnloadDirective] {
        text
            .split(separator: "\n")
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if line.hasPrefix("STEP:") {
                    let message = line.replacingOccurrences(of: "STEP:", with: "").trimmingCharacters(in: .whitespaces)
                    return UnloadDirective(kind: .step, message: message, trayName: nil, badges: [])
                }

                if line.hasPrefix("STOPPER:") {
                    let message = line.replacingOccurrences(of: "STOPPER:", with: "").trimmingCharacters(in: .whitespaces)
                    return UnloadDirective(kind: .stopper, message: message, trayName: nil, badges: [])
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
            UnloadDirective(kind: .step, message: "Solicita el numero de compra del cliente \(clientName) y confirma que corresponda a esta visita.", trayName: nil, badges: []),
            UnloadDirective(kind: .step, message: "Valida que el pedido esperado coincida con \(recommendation.finalUnload) productos previstos antes de bajar mercancia.", trayName: nil, badges: []),
            UnloadDirective(kind: .step, message: "Verifica la cantidad de productos en la tienda usando la validacion capturada por categoria.", trayName: nil, badges: []),
            UnloadDirective(kind: .step, message: "Verifica la cantidad de productos echados a perder y separalos para retiro antes del acomodo.", trayName: nil, badges: []),
            UnloadDirective(kind: .stopper, message: "Deten el proceso si el numero de compra o la merma no coincide con la validacion de tienda.", trayName: nil, badges: [])
        ]

        directives += unloadAssignmentDirectives(from: sortedAssignments)

        directives.append(
            UnloadDirective(
                kind: .stopper,
                message: "No mezcles bandejas con distinta caducidad; verifica \(sortedAssignments.first?.expirationLabel ?? "caducidad") antes de bajar la siguiente bandeja.",
                trayName: nil,
                badges: []
            )
        )

        return UnloadGuideResult(
            directives: directives.map { formattedDirective($0, assignments: sortedAssignments) },
            statusMessage: message
        )
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
                    message: "Baja la mercancia para \(assignment.productName); descarga los slots \(assignment.slotNumbers.map(String.init).joined(separator: ", ")).",
                    trayName: assignment.trayName,
                    badges: directiveBadges(wallName: assignment.wallName, shelfName: assignment.shelfName, trayName: assignment.trayName, slotNumbers: assignment.slotNumbers)
                )
            }
    }
}


struct LoadGuideGenerator {
    private let model = SystemLanguageModel.default

    func generateGuide(
        shelfName: String,
        wallName: String,
        trays: [LoadGuideTrayInput]
    ) async throws -> UnloadGuideResult {
        guard model.availability == .available else {
            return Self.fallbackGuide(
                shelfName: shelfName,
                wallName: wallName,
                trays: trays,
                message: availabilityMessage
            )
        }

        let session = LanguageModelSession(instructions: """
        Genera instrucciones operativas para acomodar cargamento en anaqueles.
        Responde solo con lineas que empiecen con STEP: o STOPPER:.
        Cada linea debe ser corta, accionable y en espanol.
        Enfocate en el orden de acomodo, produccion y cantidades por bandeja.
        No generes pasos vacios o genericos como entrar o salir.
        Incluye el detalle de pared, anaquel, bandeja, slots, cantidad y fecha de produccion.
        Para la pared usa flechas: izquierda = ←, derecha = →, frente = ↑.
        Para anaquel y bandeja usa siempre numeros, por ejemplo Anaquel 2 y Bandeja 4.
        Cuando menciones bandeja, agrega tambien el rango de indices de esa bandeja, por ejemplo Bandeja 4 (1-10) o Bandeja 4 (4-9).
        """)

        let trayText = trays.map { tray in
            "\(tray.trayName) | cliente \(tray.clientName) | \(tray.productName) | pared \(tray.wallName) | anaquel \(tray.shelfName) | slots \(tray.slotNumbers.map(String.init).joined(separator: ", ")) | cantidad \(tray.quantity) | peso \(String(format: "%.2f", tray.weightKg)) kg | produccion \(tray.productionDate)"
        }
        .joined(separator: "\n")

        let prompt = """
        Pared: \(wallName)
        Anaquel: \(shelfName)
        Bandejas a cargar:
        \(trayText)

        Genera entre 5 y 9 lineas.
        Prioriza el orden de acomodo y verificaciones antes de cerrar cada bandeja.
        Cuando menciones ubicacion usa flecha de pared, numero de anaquel, numero de bandeja y rango de indices de la bandeja.
        """

        let response = try await session.respond(to: prompt)
        let directives = parseDirectives(from: response.content).map {
            formattedDirective($0, wallName: wallName, shelfName: shelfName, trays: trays)
        }

        if directives.isEmpty {
            return Self.fallbackGuide(
                shelfName: shelfName,
                wallName: wallName,
                trays: trays,
                message: "La AI no devolvio un formato util. Se muestra una guia local."
            )
        }

        return UnloadGuideResult(
            directives: directives,
            statusMessage: "Guia de cargamento generada con Apple Intelligence."
        )
    }

    private func parseDirectives(from text: String) -> [UnloadDirective] {
        text
            .split(separator: "\n")
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                if line.hasPrefix("STEP:") {
                    let message = line.replacingOccurrences(of: "STEP:", with: "").trimmingCharacters(in: .whitespaces)
                    return UnloadDirective(kind: .step, message: message, trayName: nil, badges: [])
                }

                if line.hasPrefix("STOPPER:") {
                    let message = line.replacingOccurrences(of: "STOPPER:", with: "").trimmingCharacters(in: .whitespaces)
                    return UnloadDirective(kind: .stopper, message: message, trayName: nil, badges: [])
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
        shelfName: String,
        wallName: String,
        trays: [LoadGuideTrayInput],
        message: String?
    ) -> UnloadGuideResult {
        var directives: [UnloadDirective] = [
            UnloadDirective(kind: .step, message: "Confirma que la carga corresponde al anaquel antes de abrir la primera bandeja.", trayName: nil, badges: directiveBadges(wallName: wallName, shelfName: shelfName, trayName: nil, slotNumbers: [])),
            UnloadDirective(kind: .step, message: "Verifica que cada bandeja tenga cantidad registrada y fecha de produccion antes de acomodarla.", trayName: nil, badges: []),
            UnloadDirective(kind: .stopper, message: "Deten el acomodo si falta fecha de produccion o si una bandeja no coincide con el pedido del cliente.", trayName: nil, badges: [])
        ]

        directives += trays.prefix(6).map { tray in
            UnloadDirective(
                kind: .step,
                message: "Acomoda \(tray.quantity) productos de \(tray.productName) para \(tray.clientName) usando slots \(tray.slotNumbers.map(String.init).joined(separator: ", ")); produccion \(tray.productionDate).",
                trayName: tray.trayName,
                badges: directiveBadges(wallName: tray.wallName, shelfName: tray.shelfName, trayName: tray.trayName, slotNumbers: tray.slotNumbers)
            )
        }

        directives.append(
            UnloadDirective(
                kind: .stopper,
                message: "No cierres el anaquel hasta validar que el peso o la cantidad final de cada bandeja coincida con el registro.",
                trayName: nil,
                badges: []
            )
        )

        return UnloadGuideResult(
            directives: directives.map { formattedDirective($0, wallName: wallName, shelfName: shelfName, trays: trays) },
            statusMessage: message
        )
    }
}

private func formattedDirective(_ directive: UnloadDirective, assignments: [ClientTrayAssignment]) -> UnloadDirective {
    var badges = directive.badges
    if badges.isEmpty {
        for assignment in assignments where directive.message.contains(assignment.trayName) || directive.trayName == assignment.trayName {
            badges = directiveBadges(
                wallName: assignment.wallName,
                shelfName: assignment.shelfName,
                trayName: assignment.trayName,
                slotNumbers: assignment.slotNumbers
            )
            break
        }
    }
    return UnloadDirective(kind: directive.kind, message: cleanedDirectiveMessage(directive.message), trayName: directive.trayName, badges: badges)
}

private func formattedDirective(_ directive: UnloadDirective, wallName: String, shelfName: String, trays: [LoadGuideTrayInput]) -> UnloadDirective {
    var badges = directive.badges
    for tray in trays where directive.message.contains(tray.trayName) || directive.trayName == tray.trayName {
        badges = directiveBadges(
            wallName: tray.wallName,
            shelfName: tray.shelfName,
            trayName: tray.trayName,
            slotNumbers: tray.slotNumbers
        )
        break
    }
    if badges.isEmpty, directive.kind == .step {
        badges = directiveBadges(wallName: wallName, shelfName: shelfName, trayName: nil, slotNumbers: [])
    }
    return UnloadDirective(kind: directive.kind, message: cleanedDirectiveMessage(directive.message), trayName: directive.trayName, badges: badges)
}

private func formattedWallName(_ wallName: String) -> String {
    let normalized = wallName.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_MX")).lowercased()
    if normalized.contains("izquierda") {
        return "←"
    }
    if normalized.contains("derecha") {
        return "→"
    }
    if normalized.contains("frente") || normalized.contains("frontal") {
        return "↑"
    }
    return wallName
}

private func formattedShelfName(_ shelfName: String) -> String {
    if let digits = shelfName.firstMatch(of: /\d+/)?.output {
        return "Anaquel \(digits)"
    }
    return shelfName
}

private func formattedTrayName(_ trayName: String) -> String {
    if let digits = trayName.firstMatch(of: /\d+/)?.output {
        return "Bandeja \(digits)"
    }
    return trayName
}

private func formattedTrayReference(_ trayName: String, slotNumbers: [Int]) -> String {
    let trayLabel = formattedTrayName(trayName)
    guard let first = slotNumbers.min(), let last = slotNumbers.max() else {
        return trayLabel
    }
    return "\(trayLabel) (\(first)-\(last))"
}

private func directiveBadges(wallName: String, shelfName: String, trayName: String?, slotNumbers: [Int]) -> [String] {
    var badges = [formattedWallName(wallName), formattedShelfName(shelfName)]
    if let trayName {
        badges.append(formattedTrayReference(trayName, slotNumbers: slotNumbers))
    }
    return badges
}

private func cleanedDirectiveMessage(_ message: String) -> String {
    message
        .replacingOccurrences(of: "←, ", with: "")
        .replacingOccurrences(of: "→, ", with: "")
        .replacingOccurrences(of: "↑, ", with: "")
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
