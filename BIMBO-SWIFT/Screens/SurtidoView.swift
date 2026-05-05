import SwiftUI

struct SurtidoView: View {
    private let clients = ClientRepository.sampleClients
    private let predictor = ClientOrderPredictor()
    private let inventoryPlan: InventoryPlan

    @State private var selectedWallIndex = 1
    @State private var selectedShelfIndex = 0
    @State private var isShowingValidationModal = false
    @State private var currentClientRouteIndex = 0
    @State private var validationStep: ValidationStep = .validate
    @State private var categoryDrafts: [CategoryValidationDraft] = []
    @State private var selectedCategoryDraftID: UUID?
    @State private var aiGuideDirectives: [UnloadDirective] = []
    @State private var aiGuideStatusMessage: String?
    @State private var isGeneratingAIGuide = false
    @State private var aiGuideClientID: String?
    @State private var isNarratingGuide = false
    @State private var narratedDirectiveIndex: Int?
    @State private var awaitingDirectiveConfirmationIndex: Int?
    @State private var validatedDirectiveIndices: Set<Int> = []
    @State private var isShowingSpeechValidationSheet = false
    @State private var speechRecognizer = ValidationSpeechRecognizer()
    @State private var speechApplyStatusMessage: String?

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

    private var routeStops: [ClientRouteStop] {
        inventoryPlan.clientRoute
    }

    private var activeRouteStop: ClientRouteStop? {


        guard routeStops.indices.contains(currentClientRouteIndex) else { return nil }
        return routeStops[currentClientRouteIndex]
    }

    private var selectedCategoryIndex: Int? {
        guard let selectedCategoryDraftID else { return nil }

        return categoryDrafts.firstIndex { $0.id == selectedCategoryDraftID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeaderView(
                        title: "Surtir",
                        subtitle: "Slots ocupados con prediccion ML por cliente y validacion de tienda."
                    )

                    roomOverview
                    selectedWallSummary
                    mlSummaryCard
                    clientLegend
                    validationActionCard
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
        .sheet(isPresented: $isShowingValidationModal) {
            if let routeStop = activeRouteStop {
                validationModal(for: routeStop)
            }
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

                    Text("Cada bandeja mantiene un solo producto y una sola fecha de caducidad.")
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

            Text("La ocupacion de slots se deriva de la prediccion de la proxima semana por cliente y categoria.")
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
    
    private var validationActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Validacion de desembarque")
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            Text("Valida por categoria lo que hay en tienda y decide si capturas inventario por piezas o por peso total.")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)

            if let firstStop = routeStops.first {
                Text("Siguiente cliente en ruta: #1 \(firstStop.client.name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accentRed)
            }

            Button {
                startValidationWorkflow()
            } label: {
                Label("Iniciar validacion", systemImage: "checklist")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppColors.primaryBlue)
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

    private func startValidationWorkflow() {
        currentClientRouteIndex = 0
        validationStep = .validate
        aiGuideDirectives = []
        aiGuideStatusMessage = nil
        aiGuideClientID = nil
        narratedDirectiveIndex = nil
        awaitingDirectiveConfirmationIndex = nil
        validatedDirectiveIndices = []
        if let routeStop = activeRouteStop {
            configureDrafts(for: routeStop)
        }
        isShowingValidationModal = true
    }

    private func configureDrafts(for routeStop: ClientRouteStop) {
        categoryDrafts = routeStop.categories.map { category in
            CategoryValidationDraft(
                categoryName: category.categoryName,
                productName: category.productName,
                unitWeightKg: category.unitWeightKg,
                estimatedSales: category.suggestedSlots,
                inputMode: .units,
                currentInventoryUnitsText: "0",
                currentInventoryWeightText: "0",
                spoiledQuantityText: "0",
                replenishmentMode: .targetTotal,
                targetTotalText: String(category.suggestedSlots),
                purchaseQuantityText: String(category.suggestedSlots),
                isValidated: false
            )
        }
        selectedCategoryDraftID = categoryDrafts.first?.id
    }

    private func validationModal(for routeStop: ClientRouteStop) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cliente #\(currentClientRouteIndex + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.secondaryText)

                            Text(routeStop.client.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppColors.primaryBlue)

                            Text("ML sugiere \(routeStop.totalSlots) productos a surtir.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                        }

                        Spacer()

                        Circle()
                            .fill(routeStop.client.color)
                            .frame(width: 18, height: 18)
                    }

                    if validationStep == .validate {
                        validationStepView
                    } else {
                        unloadStepView(for: routeStop)
                    }
                }
                .padding(20)

            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Validacion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        isShowingValidationModal = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $isShowingSpeechValidationSheet) {
            validationSpeechSheet
        }
    }

    private var validationStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("1. Validacion por categoria")

            inputCard {
                Text("Captura por voz")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)

                Text("Di la categoria, las piezas actuales, echado a perder y el objetivo del cliente.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)

                Button {
                    speechRecognizer.reset()
                    speechApplyStatusMessage = nil
                    isShowingSpeechValidationSheet = true
                } label: {
                    Label("Registrar por voz", systemImage: "mic.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.accentRed)
                        )
                }
                .buttonStyle(.plain)

                if let speechApplyStatusMessage {
                    Text(speechApplyStatusMessage)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            inputCard {
                Text("Categoria")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)

                Menu {
                    ForEach(categoryDrafts) { draft in
                        Button {
                            selectedCategoryDraftID = draft.id
                        } label: {
                            Label(draft.categoryName, systemImage: draft.isValidated ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedCategory?.categoryName ?? "Selecciona una categoria")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.primaryBlue)
                            Text(selectedCategory?.productName ?? "")
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }

                        Spacer()

                        if selectedCategory?.isValidated == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.accentRed)
                        }

                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.backgroundWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }
            }

            if let selectedCategoryIndex {
                categoryValidationCard(for: selectedCategoryIndex)
            }

            Button {
                validationStep = .unload
            } label: {
                Text("Pasar a desembarque")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(hasValidatedCategories ? AppColors.accentRed : AppColors.cardBorder)
                    )
            }
            .disabled(!hasValidatedCategories)
            .buttonStyle(.plain)
        }
    }

    private var validationSpeechSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    inputCard {
                        Text("Registro por voz")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("Ejemplos: Galletas, piezas actuales 12, echado a perder 2, objetivo del cliente 20. O bien: Galletas, peso total 250 gramos, echado a perder 2, objetivo del cliente 20.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)

                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    await speechRecognizer.startRecording()
                                }
                            } label: {
                                Label(
                                    speechRecognizer.isRecording ? "Escuchando..." : "Iniciar grabacion",
                                    systemImage: "mic.fill"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(speechRecognizer.isRecording ? AppColors.cardBorder : AppColors.primaryBlue)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(speechRecognizer.isRecording)

                            Button {
                                speechRecognizer.stopRecording()
                            } label: {
                                Label("Detener", systemImage: "stop.fill")
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

                        if let errorMessage = speechRecognizer.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(AppColors.accentRed)
                        }
                    }

                    inputCard {
                        Text("Transcripcion")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.primaryBlue)

                        Text(speechRecognizer.transcript.isEmpty ? "Aun no hay texto capturado." : speechRecognizer.transcript)
                            .font(.body)
                            .foregroundStyle(AppColors.primaryBlue)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            applySpeechTranscript()
                        } label: {
                            Label("Aplicar a validacion", systemImage: "waveform.badge.magnifyingglass")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(speechRecognizer.transcript.isEmpty ? AppColors.cardBorder : AppColors.accentRed)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(speechRecognizer.transcript.isEmpty)
                    }
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Validacion por voz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        speechRecognizer.reset()
                        isShowingSpeechValidationSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var selectedCategory: CategoryValidationDraft? {
        guard let selectedCategoryIndex else { return nil }
        return categoryDrafts[selectedCategoryIndex]
    }

    private var hasValidatedCategories: Bool {
        categoryDrafts.contains(where: \.isValidated)
    }

    private func categoryValidationCard(for index: Int) -> some View {
        let unitWeightGrams = categoryDrafts[index].unitWeightKg * 1000

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryDrafts[index].categoryName)
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryBlue)
                    Text("Peso unitario: \(Int(unitWeightGrams.rounded())) gr")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                if categoryDrafts[index].isValidated {
                    Label("Validada", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accentRed)
                }
            }

            inputCard {
                Text("Producto actual en tienda")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)

                Picker("Modo de captura", selection: $categoryDrafts[index].inputMode) {
                    ForEach(InventoryInputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if categoryDrafts[index].inputMode == .units {
                    numericTextField(
                        title: "Piezas actuales",
                        text: $categoryDrafts[index].currentInventoryUnitsText,
                        prompt: "Ej. 12"
                    )
                } else {
                    numericTextField(
                        title: "Peso total en gramos",
                        text: $categoryDrafts[index].currentInventoryWeightText,
                        prompt: "Ej. 100"
                    )

                    Text("Equivale a \(unitsFromWeight(categoryDrafts[index])) piezas aprox.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            inputCard {
                numericTextField(
                    title: "Producto echado a perder",
                    text: $categoryDrafts[index].spoiledQuantityText,
                    prompt: "Ej. 3"
                )
            }

            inputCard {
                Text("Objetivo del cliente")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)

                Picker("Objetivo", selection: $categoryDrafts[index].replenishmentMode) {
                    ForEach(ReplenishmentMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if categoryDrafts[index].replenishmentMode == .targetTotal {
                    numericTextField(
                        title: "Cuanto quiere tener en total",
                        text: $categoryDrafts[index].targetTotalText,
                        prompt: "Ej. 40"
                    )
                } else {
                    numericTextField(
                        title: "Cuanto quiere comprar",
                        text: $categoryDrafts[index].purchaseQuantityText,
                        prompt: "Ej. 18"
                    )
                }
            }

            Button {
                categoryDrafts[index].isValidated = true
            } label: {
                Label("Guardar validacion", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.primaryBlue)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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

    private func sanitizedDigitsBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue.filter(\.isNumber)
            }
        )
    }

    private func applySpeechTranscript() {
        let parsed = ValidationSpeechRecognizer.parse(
            transcript: speechRecognizer.transcript,
            categories: categoryDrafts.map(\.categoryName)
        )

        if let categoryName = parsed.categoryName,
           let detectedIndex = categoryDrafts.firstIndex(where: { $0.categoryName == categoryName }) {
            selectedCategoryDraftID = categoryDrafts[detectedIndex].id
        }

        guard let selectedCategoryIndex else {
            speechApplyStatusMessage = "No se detecto una categoria valida en el audio."
            return
        }

        if let currentWeightGrams = parsed.currentWeightGrams {
            categoryDrafts[selectedCategoryIndex].inputMode = .weight
            categoryDrafts[selectedCategoryIndex].currentInventoryWeightText = String(currentWeightGrams)
            categoryDrafts[selectedCategoryIndex].currentInventoryUnitsText = ""
        } else if let currentPieces = parsed.currentPieces {
            categoryDrafts[selectedCategoryIndex].inputMode = .units
            categoryDrafts[selectedCategoryIndex].currentInventoryUnitsText = String(currentPieces)
            categoryDrafts[selectedCategoryIndex].currentInventoryWeightText = ""
        }

        if let spoiledPieces = parsed.spoiledPieces {
            categoryDrafts[selectedCategoryIndex].spoiledQuantityText = String(spoiledPieces)
        }

        if let purchaseQuantity = parsed.purchaseQuantity {
            categoryDrafts[selectedCategoryIndex].replenishmentMode = .purchaseOnly
            categoryDrafts[selectedCategoryIndex].purchaseQuantityText = String(purchaseQuantity)
        } else if let targetTotal = parsed.targetTotal {
            categoryDrafts[selectedCategoryIndex].replenishmentMode = .targetTotal
            categoryDrafts[selectedCategoryIndex].targetTotalText = String(targetTotal)
        }

        speechApplyStatusMessage = "La validacion por voz se aplico a \(categoryDrafts[selectedCategoryIndex].categoryName)."
        speechRecognizer.reset()
        isShowingSpeechValidationSheet = false
    }

    private func unloadStepView(for routeStop: ClientRouteStop) -> some View {
        let recommendation = buildUnloadRecommendation(for: routeStop)

        return VStack(alignment: .leading, spacing: 18) {
            sectionTitle("2. Desembarque")

            inputCard {
                summaryLine("Venta estimada automatica", "\(recommendation.actualSold) productos")
                summaryLine("Merma a retirar", "\(recommendation.spoiled) productos")
                summaryLine("Inventario util", "\(recommendation.usableInventory) productos")
                summaryLine("Objetivo final", "\(recommendation.targetQuantity) productos")
                summaryLine("Sugerencia ML", "\(recommendation.mlSuggested) productos")
            }

            if !recommendation.categories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Resumen por categoria")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)

                    ForEach(recommendation.categories) { category in
                        inputCard {
                            summaryLine(category.categoryName, "\(category.finalUnload) productos")
                            summaryLine("Inventario util", "\(category.usableInventory)")
                            summaryLine("Merma", "\(category.spoiled)")
                            summaryLine("Objetivo", "\(category.targetQuantity)")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Bandejas a desembarcar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)

                inputCard {
                    Text("Asistente AI de desembarque")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("Genera una guia paso a paso con steps y stopers basada en estas bandejas.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)

                    Button {
                        Task {
                            await generateAIGuide(for: routeStop, recommendation: recommendation)
                        }
                    } label: {
                        HStack {
                            if isGeneratingAIGuide {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(isGeneratingAIGuide ? "Generando guia..." : "Generar guia AI")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isGeneratingAIGuide ? AppColors.cardBorder : AppColors.primaryBlue)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isGeneratingAIGuide)

                    if let aiGuideStatusMessage {
                        Text(aiGuideStatusMessage)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    if aiGuideClientID == routeStop.client.id, !aiGuideDirectives.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    startNarration(from: 0)
                                } label: {
                                    Label(
                                        isNarratingGuide ? "Reproduciendo..." : "Narrar pasos",
                                        systemImage: "speaker.wave.2.fill"
                                    )
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
                                .disabled(isNarratingGuide)

                                Button {
                                    stopSpeakingAIGuide()
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
                                aiDirectiveCard(directive, index: index)
                            }
                        }
                    }
                }

                ForEach(routeStop.trayAssignments.filter { assignment in
                    recommendation.categories.contains { $0.categoryName == assignment.categoryName }
                }) { assignment in
                    unloadAssignmentCard(assignment, color: routeStop.client.color)
                }
            }

            HStack(spacing: 12) {
                Button {
                    validationStep = .validate
                } label: {
                    Text("Editar validacion")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    moveToNextClientOrClose()
                } label: {
                    Text(currentClientRouteIndex + 1 < routeStops.count ? "Siguiente cliente" : "Finalizar")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.primaryBlue)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func moveToNextClientOrClose() {
        if currentClientRouteIndex + 1 < routeStops.count {
            currentClientRouteIndex += 1
            validationStep = .validate
            aiGuideDirectives = []
            aiGuideStatusMessage = nil
            aiGuideClientID = nil
            narratedDirectiveIndex = nil
            awaitingDirectiveConfirmationIndex = nil
            validatedDirectiveIndices = []
            if let routeStop = activeRouteStop {
                configureDrafts(for: routeStop)
            }
        } else {
            isShowingValidationModal = false
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppColors.primaryBlue)
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

    private func summaryLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppColors.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.primaryBlue)
        }
        .font(.subheadline)
    }

    private func unloadAssignmentCard(_ assignment: ClientTrayAssignment, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.productName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("\(assignment.wallName) • \(assignment.shelfName)")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                Text(assignment.trayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.12))
                    )
            }

            Text("Slots \(assignment.slotNumbers.map(String.init).joined(separator: ", ")) • Caducidad \(assignment.expirationLabel)")
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1.5)
        )
    }

    @MainActor
    private func generateAIGuide(for routeStop: ClientRouteStop, recommendation: UnloadRecommendation) async {
        isGeneratingAIGuide = true
        aiGuideStatusMessage = nil
        aiGuideClientID = routeStop.client.id

        let assignments = routeStop.trayAssignments.filter { assignment in
            recommendation.categories.contains { $0.categoryName == assignment.categoryName }
        }

        do {
            let result = try await UnloadGuideGenerator().generateGuide(
                clientName: routeStop.client.name,
                assignments: assignments,
                recommendation: recommendation
            )
            aiGuideDirectives = result.directives
            aiGuideStatusMessage = result.statusMessage
            narratedDirectiveIndex = nil
            awaitingDirectiveConfirmationIndex = nil
            validatedDirectiveIndices = []
        } catch {
            let fallback = UnloadGuideGenerator.fallbackGuide(
                clientName: routeStop.client.name,
                assignments: assignments,
                recommendation: recommendation,
                message: "Apple Intelligence no estuvo disponible. Se muestra una guia local."
            )
            aiGuideDirectives = fallback.directives
            aiGuideStatusMessage = fallback.statusMessage
            narratedDirectiveIndex = nil
            awaitingDirectiveConfirmationIndex = nil
            validatedDirectiveIndices = []
        }

        isGeneratingAIGuide = false
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

    private func stopSpeakingAIGuide() {
        UnloadGuideNarrator.shared.stop()
        isNarratingGuide = false
        narratedDirectiveIndex = nil
        awaitingDirectiveConfirmationIndex = nil
    }

    private func confirmDirective(_ index: Int) {
        guard aiGuideDirectives.indices.contains(index) else { return }

        validatedDirectiveIndices.insert(index)
        awaitingDirectiveConfirmationIndex = nil

        guard let nextIndex = nextStepIndex(after: index) else {
            narratedDirectiveIndex = nil
            aiGuideStatusMessage = "Lectura completada. Todos los pasos narrados quedaron validados."
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

    private func aiDirectiveCard(_ directive: UnloadDirective, index: Int) -> some View {
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

    private func unitsFromWeight(_ draft: CategoryValidationDraft) -> Int {
        let grams = Double(draft.currentInventoryWeightText) ?? 0
        let unitWeightGrams = draft.unitWeightKg * 1000
        guard unitWeightGrams > 0 else { return 0 }
        return Int(floor(grams / unitWeightGrams))
    }

    private func currentInventoryUnits(for draft: CategoryValidationDraft) -> Int {
        switch draft.inputMode {
        case .units:
            return Int(draft.currentInventoryUnitsText) ?? 0
        case .weight:
            return unitsFromWeight(draft)
        }
    }

    private func buildUnloadRecommendation(for routeStop: ClientRouteStop) -> UnloadRecommendation {
        let categoryRecommendations = categoryDrafts
            .filter(\.isValidated)
            .map { draft in
                let currentInventory = currentInventoryUnits(for: draft)
                let spoiled = Int(draft.spoiledQuantityText) ?? 0
                let usableInventory = max(0, currentInventory - spoiled)
                let targetQuantity: Int

                switch draft.replenishmentMode {
                case .targetTotal:
                    targetQuantity = Int(draft.targetTotalText) ?? 0
                case .purchaseOnly:
                    targetQuantity = usableInventory + (Int(draft.purchaseQuantityText) ?? 0)
                }

                let storeNeed = max(0, targetQuantity - usableInventory)
                let demandAdjustedNeed = max(storeNeed, draft.estimatedSales + spoiled)
                let finalUnload = max(draft.estimatedSales, demandAdjustedNeed)

                return CategoryUnloadRecommendation(
                    categoryName: draft.categoryName,
                    actualSold: draft.estimatedSales,
                    spoiled: spoiled,
                    usableInventory: usableInventory,
                    targetQuantity: targetQuantity,
                    mlSuggested: draft.estimatedSales,
                    finalUnload: finalUnload
                )
            }

        let sold = categoryRecommendations.reduce(0) { $0 + $1.actualSold }
        let spoiled = categoryRecommendations.reduce(0) { $0 + $1.spoiled }
        let usableInventory = categoryRecommendations.reduce(0) { $0 + $1.usableInventory }
        let targetQuantity = categoryRecommendations.reduce(0) { $0 + $1.targetQuantity }
        let mlSuggested = categoryRecommendations.reduce(0) { $0 + $1.mlSuggested }
        let finalUnload = categoryRecommendations.reduce(0) { $0 + $1.finalUnload }

        return UnloadRecommendation(
            actualSold: sold,
            spoiled: spoiled,
            usableInventory: usableInventory,
            targetQuantity: targetQuantity,
            mlSuggested: mlSuggested,
            finalUnload: max(routeStop.totalSlots, finalUnload),
            categories: categoryRecommendations
        )
    }
}
