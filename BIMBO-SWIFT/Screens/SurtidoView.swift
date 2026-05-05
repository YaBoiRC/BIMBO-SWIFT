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
    }

    private var validationStepView: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("1. Validacion por categoria")

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

            numericTextField(
                title: "Producto echado a perder",
                text: $categoryDrafts[index].spoiledQuantityText,
                prompt: "Ej. 3"
            )

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

private enum ValidationStep {
    case validate
    case unload
}

private enum ReplenishmentMode: String, CaseIterable, Identifiable {
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

private enum InventoryInputMode: String, CaseIterable, Identifiable {
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

private struct CategoryValidationDraft: Identifiable {
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

private struct UnloadRecommendation {
    let actualSold: Int
    let spoiled: Int
    let usableInventory: Int
    let targetQuantity: Int
    let mlSuggested: Int
    let finalUnload: Int
    let categories: [CategoryUnloadRecommendation]
}

private struct CategoryUnloadRecommendation: Identifiable {
    let categoryName: String
    let actualSold: Int
    let spoiled: Int
    let usableInventory: Int
    let targetQuantity: Int
    let mlSuggested: Int
    let finalUnload: Int

    var id: String { categoryName }
}

private struct ClientRouteStop: Identifiable {
    let client: DeliveryClient
    let totalSlots: Int
    let totalTrayCount: Int
    let totalWeight: Double
    let trayAssignments: [ClientTrayAssignment]
    let categories: [ClientCategoryRoute]

    var id: String { client.id }
}

private struct ClientCategoryRoute: Identifiable {
    let categoryName: String
    let productName: String
    let unitWeightKg: Double
    let suggestedSlots: Int

    var id: String { categoryName }
}

private struct ClientTrayAssignment: Identifiable {
    let categoryName: String
    let wallName: String
    let shelfName: String
    let trayName: String
    let productName: String
    let expirationLabel: String
    let slotNumbers: [Int]

    var id: String { "\(wallName)-\(shelfName)-\(trayName)-\(productName)" }
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

    var clientRoute: [ClientRouteStop] {
        deliveryClients.compactMap { client in
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
            let categories = Dictionary(grouping: assignments, by: \.categoryName)
                .compactMap { categoryName, values -> ClientCategoryRoute? in
                    guard let first = values.first else { return nil }
                    return ClientCategoryRoute(
                        categoryName: categoryName,
                        productName: first.productName,
                        unitWeightKg: first.unitWeightKg,
                        suggestedSlots: values.reduce(0) { $0 + $1.slotNumbers.count }
                    )
                }
                .sorted { $0.categoryName < $1.categoryName }

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
            ClientSlotLoad(client: client, units: slots.filter { $0.client?.id == client.id }.count)
        }
        .filter { $0.units > 0 }
    }
}

private struct InventorySlot: Identifiable {
    let id = UUID()
    let number: Int
    let client: DeliveryClient?
}
