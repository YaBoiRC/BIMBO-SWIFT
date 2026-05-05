import SwiftUI

struct CargamentoView: View {
    private let clients = ClientRepository.sampleClients
    private let predictor = ClientOrderPredictor()
    private let inventoryPlan: InventoryPlan

    @State private var selectedWallIndex = 1
    @State private var selectedShelfIndex = 0
    @State private var manualShelvesByWall: [[InventoryShelf]] = Array(repeating: [], count: 3)
    @State private var manualTraysByShelfKey: [String: [InventoryTray]] = [:]
    @State private var trayDrafts: [TrayLoadDraft]
    @State private var aiGuideDirectives: [UnloadDirective] = []
    @State private var aiGuideStatusMessage: String?
    @State private var isGeneratingGuide = false
    @State private var isNarratingGuide = false
    @State private var narratedDirectiveIndex: Int?
    @State private var awaitingDirectiveConfirmationIndex: Int?
    @State private var validatedDirectiveIndices: Set<Int> = []
    @State private var isShowingGuideModal = false
    @State private var isShowingAddTrayCategoryPicker = false

    init() {
        let clients = ClientRepository.sampleClients
        let predictor = ClientOrderPredictor()
        let inventoryPlan = InventoryPlan.make(clients: clients, predictor: predictor)
        self.inventoryPlan = inventoryPlan

        let defaultDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 10)) ?? .now
        let drafts = inventoryPlan.walls
            .flatMap(\.shelves)
            .flatMap(\.trays)
            .enumerated()
            .map { index, tray in
                TrayLoadDraft(
                    trayID: tray.id,
                    inputMode: .units,
                    quantityText: String(max(1, tray.occupiedSlots)),
                    weightText: String(Int((tray.totalWeight * 1000).rounded())),
                    productionDate: Calendar.current.date(byAdding: .day, value: index, to: defaultDate) ?? defaultDate
                )
            }
        _trayDrafts = State(initialValue: drafts)
    }

    private var cargamentoWalls: [InventoryWall] {
        inventoryPlan.walls.enumerated().map { index, wall in
            let mergedShelves = (wall.shelves + manualShelvesByWall[index]).map { shelf in
                InventoryShelf(
                    name: shelf.name,
                    trays: shelf.trays + (manualTraysByShelfKey[shelfKey(wallName: wall.name, shelfName: shelf.name)] ?? [])
                )
            }
            return InventoryWall(name: wall.name, shelves: mergedShelves)
        }
    }

    private var selectedWall: InventoryWall {
        cargamentoWalls[selectedWallIndex]
    }

    private var selectedShelf: InventoryShelf {
        selectedWall.shelves[selectedShelfIndex]
    }

    private var selectedShelfDrafts: [TrayLoadDraft] {
        selectedShelf.trays.compactMap { tray in
            guard let draft = trayDraft(for: tray) else { return nil }
            return draft
        }
    }

    private var totalPreparedUnits: Int {
        selectedShelf.trays.reduce(0) { partial, tray in
            partial + unitsForTray(tray)
        }
    }

    private var totalPreparedWeight: Double {
        selectedShelf.trays.reduce(0.0) { partial, tray in
            partial + weightForTray(tray)
        }
    }

    private var confirmedTrayCount: Int {
        selectedShelfDrafts.filter(\.isConfirmed).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeaderView(
                        title: "Cargamento",
                        subtitle: "Prepara bandejas por cliente con cantidad o peso, fecha de produccion y guia AI de acomodo."
                    )

                    roomOverview
                    selectedWallSummary
                    cargamentoSummaryCard
                    loadingAICard
                    shelfSelector
                    selectedShelfCard
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Cargamento")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Cargamento", systemImage: "truck.box.fill")
        }
        .sheet(isPresented: $isShowingGuideModal) {
            cargamentoGuideModal
        }
        .sheet(isPresented: $isShowingAddTrayCategoryPicker) {
            addTrayCategoryModal
        }
    }

    private var roomOverview: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                wallButton(for: cargamentoWalls[0], index: 0, tall: true)
                wallButton(for: cargamentoWalls[1], index: 1, tall: false)
                wallButton(for: cargamentoWalls[2], index: 2, tall: true)
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
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("Carga preparada para llenar anaqueles por cliente")
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
            Text("Pared de cargamento")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedWall.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.accentRed)

                    Text("Cada bandeja registra cantidad o peso y una fecha de produccion.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(selectedWall.shelves.count) anaqueles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("\(selectedWall.occupiedSlots) slots destino")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)

                    Text(String(format: "%.1f kg previstos", selectedWall.totalWeight))
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            Button {
                addManualShelf()
            } label: {
                Label("Agregar anaquel manual", systemImage: "plus.rectangle.on.folder.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.accentRed)
                    )
            }
            .buttonStyle(.plain)
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

    private var cargamentoSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Carga del anaquel seleccionado")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            HStack(alignment: .top, spacing: 16) {
                summaryMetric(title: "Bandejas", value: "\(selectedShelf.trays.count)", accent: AppColors.primaryBlue)
                summaryMetric(title: "Productos", value: "\(totalPreparedUnits)", accent: AppColors.accentRed)
                summaryMetric(title: "Peso", value: String(format: "%.1f kg", totalPreparedWeight), accent: AppColors.primaryBlue)
            }

            Text("Puedes capturar por piezas o por peso total, igual que en surtido, pero enfocado al acomodo previo en anaquel.")
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

    private var loadingAICard: some View {
        inputCard {
            Text("Asistente AI de acomodo")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            Text("Genera y dicta el orden para llenar bandejas de este anaquel con fecha de produccion, cantidad y slots.")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)

            Button {
                isShowingGuideModal = true
            } label: {
                HStack {
                    Text("Abrir guia de acomodo")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.primaryBlue)
                )
            }
            .buttonStyle(.plain)

            if let aiGuideStatusMessage {
                Text(aiGuideStatusMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var cargamentoGuideModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    inputCard {
                        Text("Asistente AI de acomodo")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("La guia usa solo las bandejas confirmadas de este anaquel para dictar el orden de acomodo.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)

                        Button {
                            Task {
                                await generateLoadGuide()
                            }
                        } label: {
                            HStack {
                                if isGeneratingGuide {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(isGeneratingGuide ? "Generando guia..." : "Generar guia de acomodo")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isGeneratingGuide ? AppColors.cardBorder : AppColors.primaryBlue)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingGuide || confirmedTrayCount == 0)

                        if confirmedTrayCount == 0 {
                            Text("Confirma al menos una bandeja para generar la guia.")
                                .font(.caption)
                                .foregroundStyle(AppColors.accentRed)
                        }

                        if let aiGuideStatusMessage {
                            Text(aiGuideStatusMessage)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }

                    if !aiGuideDirectives.isEmpty {
                        inputCard {
                            HStack(spacing: 10) {
                                Button {
                                    startNarration(from: 0)
                                } label: {
                                    Label(isNarratingGuide ? "Reproduciendo..." : "Narrar pasos", systemImage: "speaker.wave.2.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(isNarratingGuide ? AppColors.cardBorder : AppColors.accentRed)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(isNarratingGuide || awaitingDirectiveConfirmationIndex != nil)

                                Button {
                                    stopSpeakingGuide()
                                } label: {
                                    Label("Detener voz", systemImage: "stop.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.primaryBlue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(AppColors.cardBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(Array(aiGuideDirectives.enumerated()), id: \.element.id) { index, directive in
                                guideDirectiveCard(directive, index: index)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Guia de acomodo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        isShowingGuideModal = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var addTrayCategoryModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Elige la categoria para inicializar producto, peso unitario y configuracion base de la bandeja.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)

                    ForEach(Self.manualTrayTemplates, id: \.categoryName) { template in
                        Button {
                            addManualTray(using: template)
                            isShowingAddTrayCategoryPicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(template.categoryName)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.primaryBlue)

                                Text(template.productName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.accentRed)

                                Text("Peso unitario \(Int((template.unitWeight * 1000).rounded())) gr")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Nueva bandeja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        isShowingAddTrayCategoryPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var shelfSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(selectedWall.shelves.enumerated()), id: \.element.id) { index, shelf in
                    Button {
                        selectedShelfIndex = index
                        resetGuideState()
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
                    Text("\(totalPreparedUnits) productos")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.accentRed)

                    Text(String(format: "%.1f kg", totalPreparedWeight))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            Button {
                isShowingAddTrayCategoryPicker = true
            } label: {
                Label("Agregar bandeja", systemImage: "plus.square.on.square.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.accentRed)
                    )
            }
            .buttonStyle(.plain)

            LazyVStack(spacing: 14) {
                ForEach(selectedShelf.trays) { tray in
                    trayLoadCard(for: tray)
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
            resetGuideState()
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

    private func addManualShelf() {
        let nextShelfNumber = cargamentoWalls[selectedWallIndex].shelves.count + 1
        let manualShelf = InventoryShelf(
            name: "Anaquel \(nextShelfNumber)",
            trays: []
        )

        manualShelvesByWall[selectedWallIndex].append(manualShelf)
        selectedShelfIndex = cargamentoWalls[selectedWallIndex].shelves.count - 1
        resetGuideState()
    }

    private func addManualTray(using template: ManualTrayTemplate) {
        let nextTrayNumber = selectedShelf.trays.count + 1
        let tray = InventoryTray(
            name: "Bandeja \(nextTrayNumber)",
            productName: template.productName,
            categoryName: template.categoryName,
            expirationLabel: "Sin asignar",
            unitWeight: template.unitWeight,
            slots: (1...10).map { InventorySlot(number: $0, client: nil) }
        )

        manualTraysByShelfKey[currentShelfKey, default: []].append(tray)
        trayDrafts.append(
            TrayLoadDraft(
                trayID: tray.id,
                inputMode: .units,
                quantityText: "0",
                weightText: "0",
                productionDate: .now
            )
        )
        resetGuideState()
    }

    private func trayLoadCard(for tray: InventoryTray) -> some View {
        guard let draftIndex = draftIndex(for: tray) else {
            return AnyView(EmptyView())
        }

        let counts = tray.deliveryCounts(clients: inventoryPlan.deliveryClients)
        let unitWeightGrams = tray.unitWeight * 1000
        let capacity = tray.slots.count

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tray.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.primaryBlue)

                        Text(tray.productName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.accentRed)

                        Text("Peso unitario: \(Int(unitWeightGrams.rounded())) gr")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(String(format: "%.1f kg", weightForTray(tray)))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("Carga registrada")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)

                        trayLoadGrid(for: tray)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(counts) { load in
                            Label("\(load.client.name): \(load.units) slots", systemImage: "circle.fill")
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

                Text("Produccion")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)

                DatePicker(
                    "",
                    selection: $trayDrafts[draftIndex].productionDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()

                Picker("Modo", selection: $trayDrafts[draftIndex].inputMode) {
                    ForEach(InventoryInputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if trayDrafts[draftIndex].inputMode == .units {
                    numericTextField(
                        title: "Cantidad de productos",
                        text: limitedDigitsBinding(
                            $trayDrafts[draftIndex].quantityText,
                            maxValue: capacity
                        ),
                        prompt: "Max. \(capacity)"
                    )
                } else {
                    numericTextField(
                        title: "Peso total en gramos",
                        text: limitedDigitsBinding(
                            $trayDrafts[draftIndex].weightText,
                            maxValue: Int((Double(capacity) * unitWeightGrams).rounded())
                        ),
                        prompt: "Max. \(Int((Double(capacity) * unitWeightGrams).rounded()))"
                    )

                    Text("Equivale a \(unitsForTray(tray)) productos aprox. de \(capacity) max.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Button {
                    trayDrafts[draftIndex].isConfirmed.toggle()
                } label: {
                    Label(
                        trayDrafts[draftIndex].isConfirmed ? "Quitar confirmacion" : "Confirmar cantidad o peso",
                        systemImage: trayDrafts[draftIndex].isConfirmed ? "xmark.circle.fill" : "checkmark.seal.fill"
                    )
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(trayDrafts[draftIndex].isConfirmed ? AppColors.accentRed : AppColors.primaryBlue)
                    )
                }
                .buttonStyle(.plain)

                if trayDrafts[draftIndex].isConfirmed {
                    Text("Se usara esta captura para la guia de acomodo del cargamento.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
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
        )
    }

    @MainActor
    private func generateLoadGuide() async {
        isGeneratingGuide = true
        aiGuideStatusMessage = nil
        resetGuideProgress()

        let inputs = selectedShelf.trays.compactMap { tray -> LoadGuideTrayInput? in
            guard let draft = trayDraft(for: tray), draft.isConfirmed else { return nil }
            let counts = tray.deliveryCounts(clients: inventoryPlan.deliveryClients)
            guard let primaryClient = counts.max(by: { $0.units < $1.units })?.client else { return nil }
            return LoadGuideTrayInput(
                clientName: primaryClient.name,
                trayName: tray.name,
                wallName: selectedWall.name,
                shelfName: selectedShelf.name,
                productName: tray.productName,
                slotNumbers: tray.slots.map(\.number),
                quantity: unitsForTray(tray),
                weightKg: weightForTray(tray),
                productionDate: formattedProductionDate(for: tray)
            )
        }

        do {
            let result = try await LoadGuideGenerator().generateGuide(
                shelfName: selectedShelf.name,
                wallName: selectedWall.name,
                trays: inputs
            )
            aiGuideDirectives = result.directives
            aiGuideStatusMessage = result.statusMessage
        } catch {
            let fallback = LoadGuideGenerator.fallbackGuide(
                shelfName: selectedShelf.name,
                wallName: selectedWall.name,
                trays: inputs,
                message: "Apple Intelligence no estuvo disponible. Se muestra una guia local."
            )
            aiGuideDirectives = fallback.directives
            aiGuideStatusMessage = fallback.statusMessage
        }

        isGeneratingGuide = false
    }

    private func startNarration(from index: Int) {
        guard aiGuideDirectives.indices.contains(index) else { return }
        guard awaitingDirectiveConfirmationIndex == nil else { return }

        let nextIndex = aiGuideDirectives[index].kind == .step ? index : nextStepIndex(after: index - 1)
        guard let directiveIndex = nextIndex else { return }
        speakDirective(at: directiveIndex)
    }

    private func speakDirective(at index: Int) {
        guard aiGuideDirectives.indices.contains(index) else { return }

        let directive = aiGuideDirectives[index]
        let prefix = directive.kind == .step ? "Paso \(stepNumber(for: index))." : "Alerta."
        isNarratingGuide = true
        narratedDirectiveIndex = index
        awaitingDirectiveConfirmationIndex = nil
        UnloadGuideNarrator.shared.speak(
            text: "\(prefix) \(directive.message)",
            onFinish: {
                isNarratingGuide = false
                awaitingDirectiveConfirmationIndex = index
            }
        )
    }

    private func stopSpeakingGuide() {
        UnloadGuideNarrator.shared.stop()
        isNarratingGuide = false
        narratedDirectiveIndex = nil
        awaitingDirectiveConfirmationIndex = nil
    }

    private func confirmDirective(_ index: Int) {
        validatedDirectiveIndices.insert(index)
        awaitingDirectiveConfirmationIndex = nil

        guard let nextIndex = nextStepIndex(after: index) else {
            narratedDirectiveIndex = nil
            aiGuideStatusMessage = "Lectura completada. Todo el acomodo del anaquel fue validado."
            return
        }

        speakDirective(at: nextIndex)
    }

    private func nextStepIndex(after index: Int) -> Int? {
        let start = max(0, index + 1)
        return aiGuideDirectives.indices.first { candidate in
            candidate >= start && aiGuideDirectives[candidate].kind == .step
        }
    }

    private func stepNumber(for index: Int) -> Int {
        aiGuideDirectives[..<index].reduce(0) { partial, directive in
            partial + (directive.kind == .step ? 1 : 0)
        } + 1
    }

    private func guideDirectiveCard(_ directive: UnloadDirective, index: Int) -> some View {
        let isStep = directive.kind == .step
        let isAwaitingConfirmation = awaitingDirectiveConfirmationIndex == index
        let isNarratingThisDirective = narratedDirectiveIndex == index && isNarratingGuide
        let isValidated = validatedDirectiveIndices.contains(index)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    isStep ? "STEP" : "STOPPER",
                    systemImage: isStep ? "list.number" : "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(isStep ? AppColors.primaryBlue : AppColors.accentRed)

                Spacer()

                if isValidated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.accentRed)
                }

                if !directive.badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(directive.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(AppColors.primaryBlue.opacity(0.08))
                                )
                        }
                    }
                }
            }

            Text(directive.message)
                .font(.subheadline)
                .foregroundStyle(AppColors.primaryBlue)

            if isStep {
                HStack(spacing: 10) {
                    Button {
                        startNarration(from: index)
                    } label: {
                        Label(
                            isNarratingThisDirective ? "Leyendo..." : "Escuchar desde aqui",
                            systemImage: "speaker.wave.2.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isNarratingThisDirective ? AppColors.cardBorder : AppColors.primaryBlue)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isNarratingGuide || awaitingDirectiveConfirmationIndex != nil)

                    if isAwaitingConfirmation {
                        Button {
                            confirmDirective(index)
                        } label: {
                            Label("Validar y seguir", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.primaryBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isAwaitingConfirmation
                    ? AppColors.primaryBlue.opacity(0.08)
                    : (isStep ? Color.white : AppColors.accentRed.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isAwaitingConfirmation
                    ? AppColors.primaryBlue.opacity(0.35)
                    : (isStep ? AppColors.cardBorder : AppColors.accentRed.opacity(0.35)),
                    lineWidth: 1
                )
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

    private func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }

    private func numericTextField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryBlue)

            TextField(prompt, text: sanitizedDigitsBinding(text))
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func limitedDigitsBinding(_ binding: Binding<String>, maxValue: Int) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                guard !digits.isEmpty else {
                    binding.wrappedValue = ""
                    return
                }

                let parsed = Int(digits) ?? 0
                binding.wrappedValue = String(min(parsed, maxValue))
            }
        )
    }

    private func sanitizedDigitsBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue.filter(\.isNumber)
            }
        )
    }

    private func trayLoadGrid(for tray: InventoryTray) -> some View {
        let filledCount = unitsForTray(tray)
        let columns = Array(repeating: GridItem(.fixed(16), spacing: 6), count: 5)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<tray.slots.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(index < filledCount ? AppColors.accentRed : AppColors.backgroundWhite)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(
                                index < filledCount ? AppColors.accentRed : AppColors.cardBorder,
                                lineWidth: 1
                            )
                    )
            }
        }
    }

    private func draftIndex(for tray: InventoryTray) -> Int? {
        trayDrafts.firstIndex { $0.trayID == tray.id }
    }

    private func trayDraft(for tray: InventoryTray) -> TrayLoadDraft? {
        guard let index = draftIndex(for: tray) else { return nil }
        return trayDrafts[index]
    }

    private func unitsForTray(_ tray: InventoryTray) -> Int {
        guard let draft = trayDraft(for: tray) else { return 0 }
        switch draft.inputMode {
        case .units:
            return min(Int(draft.quantityText) ?? 0, tray.slots.count)
        case .weight:
            let grams = Double(draft.weightText) ?? 0
            let unitWeightGrams = tray.unitWeight * 1000
            guard unitWeightGrams > 0 else { return 0 }
            return min(Int(floor(grams / unitWeightGrams)), tray.slots.count)
        }
    }

    private func weightForTray(_ tray: InventoryTray) -> Double {
        guard let draft = trayDraft(for: tray) else { return 0 }
        switch draft.inputMode {
        case .units:
            let units = Double(Int(draft.quantityText) ?? 0)
            return units * tray.unitWeight
        case .weight:
            let grams = Double(draft.weightText) ?? 0
            return grams / 1000
        }
    }

    private func formattedProductionDate(for tray: InventoryTray) -> String {
        guard let draft = trayDraft(for: tray) else { return "" }
        return Self.productionDateFormatter.string(from: draft.productionDate)
    }

    private func resetGuideState() {
        aiGuideDirectives = []
        aiGuideStatusMessage = nil
        resetGuideProgress()
    }

    private func resetGuideProgress() {
        narratedDirectiveIndex = nil
        awaitingDirectiveConfirmationIndex = nil
        validatedDirectiveIndices = []
    }

    private static let productionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let manualTrayTemplates: [ManualTrayTemplate] = [
        ManualTrayTemplate(
            categoryName: "Pan de caja fresco y congelado",
            productName: "Pan Blanco Grande",
            unitWeight: 0.68
        ),
        ManualTrayTemplate(
            categoryName: "Bollos, English muffins y bagels",
            productName: "Bollos Clasicos",
            unitWeight: 0.05
        ),
        ManualTrayTemplate(
            categoryName: "Botanas saladas",
            productName: "Botana Horneada",
            unitWeight: 0.08
        ),
        ManualTrayTemplate(
            categoryName: "Galletas",
            productName: "Galletas Avena",
            unitWeight: 0.026
        )
    ]

    private var currentShelfKey: String {
        shelfKey(wallName: selectedWall.name, shelfName: selectedShelf.name)
    }

    private func shelfKey(wallName: String, shelfName: String) -> String {
        "\(wallName)|\(shelfName)"
    }
}

private struct ManualTrayTemplate {
    let categoryName: String
    let productName: String
    let unitWeight: Double
}

private struct TrayLoadDraft: Identifiable {
    let id = UUID()
    let trayID: UUID
    var inputMode: InventoryInputMode
    var quantityText: String
    var weightText: String
    var productionDate: Date
    var isConfirmed: Bool = false
}
