import SwiftUI

enum ValidationStep {
    case validate
    case unload
}

enum ReplenishmentMode: String, CaseIterable, Identifiable {
    case targetTotal
    case purchaseOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .targetTotal: return "Tener total"
        case .purchaseOnly: return "Comprar"
        }
    }
}

enum InventoryInputMode: String, CaseIterable, Identifiable {
    case units
    case weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .units: return "Piezas"
        case .weight: return "Peso"
        }
    }
}

struct DeliveryClient: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let color: Color
    let foregroundColor: Color
}

struct ClientSlotLoad: Identifiable {
    let client: DeliveryClient
    let units: Int

    var id: String { client.id }
}

struct CategoryValidationDraft: Identifiable {
    let id = UUID()
    let categoryName: String
    let productName: String
    let unitWeightKg: Double
    let estimatedSales: Int
    var inputMode: InventoryInputMode
    var currentInventoryUnitsText: String
    var currentInventoryWeightText: String
    var spoiledQuantityText: String
    var replenishmentMode: ReplenishmentMode
    var targetTotalText: String
    var purchaseQuantityText: String
    var isValidated: Bool
}

struct UnloadRecommendation {
    let actualSold: Int
    let spoiled: Int
    let usableInventory: Int
    let targetQuantity: Int
    let mlSuggested: Int
    let finalUnload: Int
    let categories: [CategoryUnloadRecommendation]
}

enum UnloadDirectiveKind {
    case step
    case stopper
}

struct UnloadDirective: Identifiable {
    let id = UUID()
    let kind: UnloadDirectiveKind
    let message: String
    let trayName: String?
    let badges: [String]
}

struct UnloadGuideResult {
    let directives: [UnloadDirective]
    let statusMessage: String?
}

struct CategoryUnloadRecommendation: Identifiable {
    let categoryName: String
    let actualSold: Int
    let spoiled: Int
    let usableInventory: Int
    let targetQuantity: Int
    let mlSuggested: Int
    let finalUnload: Int

    var id: String { categoryName }
}

struct ClientRouteStop: Identifiable {
    let client: DeliveryClient
    let totalSlots: Int
    let totalTrayCount: Int
    let totalWeight: Double
    let trayAssignments: [ClientTrayAssignment]
    let categories: [ClientCategoryRoute]

    var id: String { client.id }
}

struct ClientCategoryRoute: Identifiable {
    let categoryName: String
    let productName: String
    let unitWeightKg: Double
    let suggestedSlots: Int

    var id: String { categoryName }
}

struct ClientTrayAssignment: Identifiable {
    let categoryName: String
    let wallName: String
    let shelfName: String
    let trayName: String
    let productName: String
    let unitWeightKg: Double
    let expirationLabel: String
    let slotNumbers: [Int]

    var id: String { "\(wallName)-\(shelfName)-\(trayName)-\(productName)" }
}

struct InventoryPlan {
    let deliveryClients: [DeliveryClient]
    let walls: [InventoryWall]

    var totalOccupiedSlots: Int {
        walls.reduce(0) { $0 + $1.occupiedSlots }
    }

    var totalWeight: Double {
        walls.reduce(0) { $0 + $1.totalWeight }
    }

    var clientRoute: [ClientRouteStop] {
        deliveryClients.compactMap { client -> ClientRouteStop? in
            let assignments = clientAssignments(for: client)
            guard !assignments.isEmpty else { return nil }

            let totalSlots = assignments.reduce(0) { $0 + $1.slotNumbers.count }
            let totalTrayCount = assignments.count
            let totalWeight = walls.reduce(0.0) { partial, wall in
                partial + wall.shelves.reduce(0.0) { shelfPartial, shelf in
                    shelfPartial + shelf.trays.reduce(0.0) { trayPartial, tray in
                        let count = tray.slots.filter { $0.client?.id == client.id }.count
                        return trayPartial + (Double(count) * tray.unitWeight)
                    }
                }
            }
            let groupedAssignments = Dictionary(grouping: assignments, by: \.categoryName)
            let categories = groupedAssignments.compactMap { categoryName, values -> ClientCategoryRoute? in
                guard let first = values.first else { return nil }
                let suggestedSlots = values.reduce(0) { partial, assignment in
                    partial + assignment.slotNumbers.count
                }

                return ClientCategoryRoute(
                    categoryName: categoryName,
                    productName: first.productName,
                    unitWeightKg: first.unitWeightKg,
                    suggestedSlots: suggestedSlots
                )
            }
            .sorted { lhs, rhs in
                lhs.categoryName < rhs.categoryName
            }

            return ClientRouteStop(
                client: client,
                totalSlots: totalSlots,
                totalTrayCount: totalTrayCount,
                totalWeight: totalWeight,
                trayAssignments: assignments,
                categories: categories
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalSlots != rhs.totalSlots {
                return lhs.totalSlots > rhs.totalSlots
            }
            return lhs.client.name < rhs.client.name
        }
    }

    static func make(clients: [Client], predictor: ClientOrderPredictor) -> InventoryPlan {
        let mappedClients = clients.prefix(4).enumerated().map { index, client in
            DeliveryClient(
                id: client.id,
                name: client.name,
                shortName: shortName(for: client.name),
                color: palette[index].fill,
                foregroundColor: palette[index].foreground
            )
        }

        let trayTemplates = trayTemplateCatalog
        let slotForecasts = mappedClients.flatMap { deliveryClient in
            guard let client = clients.first(where: { $0.id == deliveryClient.id }) else {
                return [ForecastLoad]()
            }

            return predictor.predictions(for: client).compactMap { prediction in
                guard let template = trayTemplates.first(where: { $0.categoryName == prediction.categoryName }) else {
                    return nil
                }

                let slotCount = max(1, Int(ceil(prediction.predictedNextOrder / template.unitsPerSlot)))
                return ForecastLoad(
                    client: deliveryClient,
                    categoryName: prediction.categoryName,
                    productName: template.productName,
                    expirationLabel: template.expirationLabel,
                    unitWeight: template.unitWeight,
                    slotCount: slotCount
                )
            }
        }

        let trays = buildTrays(from: slotForecasts)
        let shelves = buildShelves(from: trays)
        let walls = buildWalls(from: shelves)

        return InventoryPlan(deliveryClients: mappedClients, walls: walls)
    }

    private func clientAssignments(for client: DeliveryClient) -> [ClientTrayAssignment] {
        walls.flatMap { wall in
            wall.shelves.flatMap { shelf in
                shelf.trays.compactMap { tray in
                    let slots = tray.slots.filter { $0.client?.id == client.id }.map(\.number)
                    guard !slots.isEmpty else { return nil }

                    return ClientTrayAssignment(
                        categoryName: tray.categoryName,
                        wallName: wall.name,
                        shelfName: shelf.name,
                        trayName: tray.name,
                        productName: tray.productName,
                        unitWeightKg: tray.unitWeight,
                        expirationLabel: tray.expirationLabel,
                        slotNumbers: slots
                    )
                }
            }
        }
    }

    private static func buildTrays(from forecasts: [ForecastLoad]) -> [InventoryTray] {
        var trays: [InventoryTray] = []
        var trayNumber = 1

        for forecast in forecasts.sorted(by: { lhs, rhs in
            if lhs.categoryName != rhs.categoryName {
                return lhs.categoryName < rhs.categoryName
            }
            if lhs.client.name != rhs.client.name {
                return lhs.client.name < rhs.client.name
            }
            return lhs.productName < rhs.productName
        }) {
            var remainingSlots = forecast.slotCount

            while remainingSlots > 0 {
                let occupiedCount = min(10, remainingSlots)
                let slots = (1...10).map { slotNumber in
                    InventorySlot(number: slotNumber, client: slotNumber <= occupiedCount ? forecast.client : nil)
                }

                trays.append(
                    InventoryTray(
                        name: "Bandeja \(trayNumber)",
                        productName: forecast.productName,
                        categoryName: forecast.categoryName,
                        expirationLabel: forecast.expirationLabel,
                        unitWeight: forecast.unitWeight,
                        slots: slots
                    )
                )

                trayNumber += 1
                remainingSlots -= occupiedCount
            }
        }

        return trays
    }

    private static func buildShelves(from trays: [InventoryTray]) -> [InventoryShelf] {
        let shelvesNeeded = max(6, Int(ceil(Double(trays.count) / 10.0)))
        let shelfNames = (1...shelvesNeeded).map { "Anaquel \($0)" }

        return shelfNames.enumerated().map { index, shelfName in
            let start = index * 10
            let end = min(start + 10, trays.count)
            let shelfTrays = start < end ? Array(trays[start..<end]) : []
            return InventoryShelf(name: shelfName, trays: shelfTrays)
        }
    }

    private static func buildWalls(from shelves: [InventoryShelf]) -> [InventoryWall] {
        let wallNames = ["Pared izquierda", "Pared frontal", "Pared derecha"]
        let perWall = Int(ceil(Double(shelves.count) / Double(wallNames.count)))

        return wallNames.enumerated().map { index, name in
            let start = index * perWall
            let end = min(start + perWall, shelves.count)
            let wallShelves = start < end ? Array(shelves[start..<end]) : []
            return InventoryWall(name: name, shelves: wallShelves)
        }
    }

    private static func shortName(for name: String) -> String {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "CL" : initials
    }

    private static let palette: [(fill: Color, foreground: Color)] = [
        (fill: Color(red: 0.10, green: 0.56, blue: 0.98), foreground: Color(red: 0.05, green: 0.27, blue: 0.53)),
        (fill: Color(red: 0.14, green: 0.71, blue: 0.42), foreground: Color(red: 0.05, green: 0.34, blue: 0.20)),
        (fill: Color(red: 0.98, green: 0.68, blue: 0.16), foreground: Color(red: 0.51, green: 0.29, blue: 0.00)),
        (fill: Color(red: 0.80, green: 0.35, blue: 0.85), foreground: Color(red: 0.39, green: 0.11, blue: 0.44))
    ]

    private static let trayTemplateCatalog: [TrayTemplate] = [
        TrayTemplate(categoryName: "Pan de caja fresco y congelado", productName: "Pan Blanco Grande", expirationLabel: "14 May 2026", unitWeight: 0.68, unitsPerSlot: 40),
        TrayTemplate(categoryName: "Bollos, English muffins y bagels", productName: "Bollos Clasicos", expirationLabel: "16 May 2026", unitWeight: 0.05, unitsPerSlot: 24),
        TrayTemplate(categoryName: "Botanas saladas", productName: "Botana Horneada", expirationLabel: "22 May 2026", unitWeight: 0.08, unitsPerSlot: 18),
        TrayTemplate(categoryName: "Galletas", productName: "Galletas Avena", expirationLabel: "19 May 2026", unitWeight: 0.026, unitsPerSlot: 16)
    ]
}

struct ForecastLoad {
    let client: DeliveryClient
    let categoryName: String
    let productName: String
    let expirationLabel: String
    let unitWeight: Double
    let slotCount: Int
}

struct TrayTemplate {
    let categoryName: String
    let productName: String
    let expirationLabel: String
    let unitWeight: Double
    let unitsPerSlot: Double
}

struct InventoryWall: Identifiable {
    let id = UUID()
    let name: String
    let shelves: [InventoryShelf]

    var occupiedSlots: Int {
        shelves.reduce(0) { $0 + $1.occupiedSlots }
    }

    var totalWeight: Double {
        shelves.reduce(0) { $0 + $1.totalWeight }
    }
}

struct InventoryShelf: Identifiable {
    let id = UUID()
    let name: String
    let trays: [InventoryTray]

    var occupiedSlots: Int {
        trays.reduce(0) { $0 + $1.occupiedSlots }
    }

    var totalWeight: Double {
        trays.reduce(0) { $0 + $1.totalWeight }
    }

    func deliveryCounts(clients: [DeliveryClient]) -> [ClientSlotLoad] {
        clients.map { client in
            ClientSlotLoad(
                client: client,
                units: trays.reduce(0) { partial, tray in
                    partial + tray.slots.filter { $0.client?.id == client.id }.count
                }
            )
        }
        .filter { $0.units > 0 }
    }
}

struct InventoryTray: Identifiable {
    let id = UUID()
    let name: String
    let productName: String
    let categoryName: String
    let expirationLabel: String
    let unitWeight: Double
    let slots: [InventorySlot]

    var occupiedSlots: Int {
        slots.filter { $0.client != nil }.count
    }

    var totalWeight: Double {
        Double(occupiedSlots) * unitWeight
    }

    func deliveryCounts(clients: [DeliveryClient]) -> [ClientSlotLoad] {
        clients.map { client in
            ClientSlotLoad(client: client, units: slots.filter { $0.client?.id == client.id }.count)
        }
        .filter { $0.units > 0 }
    }
}

struct InventorySlot: Identifiable {
    let id = UUID()
    let number: Int
    let client: DeliveryClient?
}
