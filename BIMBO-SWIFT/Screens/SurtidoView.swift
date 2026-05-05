import SwiftUI

struct SurtidoView: View {
    private let clients = ClientRepository.sampleClients
    private let predictor = ClientOrderPredictor()
    private let inventoryPlan: InventoryPlan

    @State private var selectedWallIndex = 1
    @State private var selectedShelfIndex = 0

    init() {
        let clients = ClientRepository.sampleClients
        let predictor = ClientOrderPredictor()
        self.inventoryPlan = InventoryPlan.make(clients: clients, predictor: predictor)
    }

    private var selectedWall: InventoryWall {
        inventoryPlan.walls[selectedWallIndex]
    }

    private var selectedShelf: InventoryShelf {
        selectedWall.shelves[selectedShelfIndex]
    }

    private var shelfDeliveryCounts: [ClientSlotLoad] {
        selectedShelf.deliveryCounts(clients: inventoryPlan.deliveryClients)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeaderView(
                        title: "Surtir",
                        subtitle: "Slots ocupados con prediccion ML por cliente y rotacion FIFO semanal."
                    )

                    roomOverview
                    selectedWallSummary
                    mlSummaryCard
                    clientLegend
                    shelfSelector
                    selectedShelfCard
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Surtido")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Surtir", systemImage: "shippingbox.circle.fill")
        }
    }

    private var roomOverview: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                wallButton(for: inventoryPlan.walls[0], index: 0, tall: true)
                wallButton(for: inventoryPlan.walls[1], index: 1, tall: false)
                wallButton(for: inventoryPlan.walls[2], index: 2, tall: true)
            }

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, AppColors.backgroundWhite],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 100)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "brain.filled.head.profile")
                            .font(.title2)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("Surtido generado desde prediccion semanal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
        }
    }

    private var selectedWallSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pared seleccionada")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedWall.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.accentRed)

                    Text("Los productos salen en Queue del slot 1 al 10. Cuando se rellena una bandeja, vuelve a iniciar desde el slot 1 la siguiente semana.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(selectedWall.shelves.count) anaqueles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("\(selectedWall.occupiedSlots) slots ocupados")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)

                    Text(String(format: "%.1f kg", selectedWall.totalWeight))
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var mlSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Carga prevista por ML")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            HStack(alignment: .top, spacing: 16) {
                summaryMetric(
                    title: "Clientes",
                    value: "\(inventoryPlan.deliveryClients.count)",
                    accent: AppColors.primaryBlue
                )
                summaryMetric(
                    title: "Slots ocupados",
                    value: "\(inventoryPlan.totalOccupiedSlots)",
                    accent: AppColors.accentRed
                )
                summaryMetric(
                    title: "Peso total",
                    value: String(format: "%.1f kg", inventoryPlan.totalWeight),
                    accent: AppColors.primaryBlue
                )
            }

            Text("La ocupacion de slots se deriva de la prediccion de la proxima semana por cliente y categoria, convertida a capacidad de bandeja.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func summaryMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clientLegend: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Clientes y entrega prevista")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(shelfDeliveryCounts) { load in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(load.client.color)
                                .frame(width: 14, height: 14)
                                .shadow(color: load.client.color.opacity(0.35), radius: 6, x: 0, y: 0)

                            Text(load.client.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.primaryBlue)
                                .lineLimit(2)
                        }

                        Text("\(load.units) slots")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(load.client.color)

                        Text("Color visible en los slots ocupados.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(load.client.color.opacity(0.25), lineWidth: 1.5)
                    )
                }
            }
        }
    }

    private var shelfSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(selectedWall.shelves.enumerated()), id: \.element.id) { index, shelf in
                    Button {
                        selectedShelfIndex = index
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(shelf.name)
                                .font(.subheadline.weight(.semibold))

                            Text("\(shelf.trays.count) bandejas")
                                .font(.caption)
                        }
                        .foregroundStyle(selectedShelfIndex == index ? Color.white : AppColors.primaryBlue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedShelfIndex == index ? AppColors.primaryBlue : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    selectedShelfIndex == index ? AppColors.primaryBlue : AppColors.cardBorder,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedShelfCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedShelf.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("\(selectedWall.name) • \(selectedShelf.trays.count) bandejas • 10 slots por bandeja")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(selectedShelf.occupiedSlots) slots")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.accentRed)

                    Text(String(format: "%.1f kg", selectedShelf.totalWeight))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            LazyVStack(spacing: 14) {
                ForEach(selectedShelf.trays) { tray in
                    trayCard(for: tray)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .shadow(color: AppColors.primaryBlue.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private func wallButton(for wall: InventoryWall, index: Int, tall: Bool) -> some View {
        Button {
            selectedWallIndex = index
            selectedShelfIndex = 0
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(wall.name)
                    .font(.subheadline.weight(.bold))

                Text("\(wall.shelves.count) anaqueles")
                    .font(.caption)
                    .foregroundStyle(selectedWallIndex == index ? Color.white.opacity(0.88) : AppColors.secondaryText)
            }
            .foregroundStyle(selectedWallIndex == index ? Color.white : AppColors.primaryBlue)
            .frame(maxWidth: .infinity, minHeight: tall ? 132 : 108, alignment: .topLeading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(selectedWallIndex == index ? AppColors.primaryBlue : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        selectedWallIndex == index ? AppColors.primaryBlue : AppColors.cardBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: selectedWallIndex == index ? AppColors.primaryBlue.opacity(0.18) : AppColors.primaryBlue.opacity(0.06),
                radius: selectedWallIndex == index ? 18 : 8,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }

    private func trayCard(for tray: InventoryTray) -> some View {
        let counts = tray.deliveryCounts(clients: inventoryPlan.deliveryClients)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tray.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text(tray.productName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accentRed)

                    Text("Caducidad: \(tray.expirationLabel)")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(String(format: "%.1f kg", tray.totalWeight))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("Peso total")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            HStack {
                Text("Queue FIFO 1 -> 10")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.primaryBlue)

                Spacer()

                Text("\(tray.occupiedSlots) / 10 ocupados")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }

            slotGrid(for: tray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(counts) { load in
                        Label("\(load.client.name): \(load.units)", systemImage: "circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(load.client.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(load.client.color.opacity(0.12))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.cardBorder.opacity(0.9), lineWidth: 1)
        )
    }

    private func slotGrid(for tray: InventoryTray) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
            spacing: 8
        ) {
            ForEach(tray.slots) { slot in
                slotView(slot)
            }
        }
    }

    private func slotView(_ slot: InventorySlot) -> some View {
        VStack(spacing: 4) {
            Text("\(slot.number)")
                .font(.headline.weight(.bold))
                .foregroundStyle(slot.client?.foregroundColor ?? AppColors.secondaryText)

            Text(slot.client?.shortName ?? "Libre")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(slot.client?.foregroundColor ?? AppColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(slot.client?.color.opacity(0.18) ?? Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(slot.client?.color.opacity(0.65) ?? AppColors.cardBorder, lineWidth: 1.5)
        )
        .shadow(
            color: slot.client?.color.opacity(0.22) ?? .clear,
            radius: slot.client == nil ? 0 : 8,
            x: 0,
            y: 4
        )
    }
}

private struct DeliveryClient: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let color: Color
    let foregroundColor: Color
}

private struct ClientSlotLoad: Identifiable {
    let client: DeliveryClient
    let units: Int

    var id: String { client.id }
}

private struct InventoryPlan {
    let deliveryClients: [DeliveryClient]
    let walls: [InventoryWall]

    var totalOccupiedSlots: Int {
        walls.reduce(0) { $0 + $1.occupiedSlots }
    }

    var totalWeight: Double {
        walls.reduce(0) { $0 + $1.totalWeight }
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
                    InventorySlot(
                        number: slotNumber,
                        client: slotNumber <= occupiedCount ? forecast.client : nil
                    )
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
        (
            fill: Color(red: 0.10, green: 0.56, blue: 0.98),
            foreground: Color(red: 0.05, green: 0.27, blue: 0.53)
        ),
        (
            fill: Color(red: 0.14, green: 0.71, blue: 0.42),
            foreground: Color(red: 0.05, green: 0.34, blue: 0.20)
        ),
        (
            fill: Color(red: 0.98, green: 0.68, blue: 0.16),
            foreground: Color(red: 0.51, green: 0.29, blue: 0.00)
        ),
        (
            fill: Color(red: 0.80, green: 0.35, blue: 0.85),
            foreground: Color(red: 0.39, green: 0.11, blue: 0.44)
        )
    ]

    private static let trayTemplateCatalog: [TrayTemplate] = [
        TrayTemplate(
            categoryName: "Pan de caja fresco y congelado",
            productName: "Pan Blanco Grande",
            expirationLabel: "14 May 2026",
            unitWeight: 0.68,
            unitsPerSlot: 40
        ),
        TrayTemplate(
            categoryName: "Bollos, English muffins y bagels",
            productName: "Bollos Clasicos",
            expirationLabel: "16 May 2026",
            unitWeight: 0.54,
            unitsPerSlot: 24
        ),
        TrayTemplate(
            categoryName: "Botanas saladas",
            productName: "Botana Horneada",
            expirationLabel: "22 May 2026",
            unitWeight: 0.22,
            unitsPerSlot: 18
        ),
        TrayTemplate(
            categoryName: "Galletas",
            productName: "Galletas Avena",
            expirationLabel: "19 May 2026",
            unitWeight: 0.26,
            unitsPerSlot: 16
        )
    ]
}

private struct ForecastLoad {
    let client: DeliveryClient
    let categoryName: String
    let productName: String
    let expirationLabel: String
    let unitWeight: Double
    let slotCount: Int
}

private struct TrayTemplate {
    let categoryName: String
    let productName: String
    let expirationLabel: String
    let unitWeight: Double
    let unitsPerSlot: Double
}

private struct InventoryWall: Identifiable {
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

private struct InventoryShelf: Identifiable {
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

private struct InventoryTray: Identifiable {
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
            ClientSlotLoad(
                client: client,
                units: slots.filter { $0.client?.id == client.id }.count
            )
        }
        .filter { $0.units > 0 }
    }
}

private struct InventorySlot: Identifiable {
    let id = UUID()
    let number: Int
    let client: DeliveryClient?
}
