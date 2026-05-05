import SwiftUI

struct SurtidoView: View {
    private let walls = StorageWall.sampleWalls
    @State private var selectedWallIndex = 1
    @State private var selectedShelfIndex = 0

    private var selectedWall: StorageWall {
        walls[selectedWallIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeaderView(
                        title: "Surtir",
                        subtitle: "Cuarto de 3 paredes con anaqueles, bandejas y slots enumerados."
                    )

                    roomOverview

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Pared seleccionada")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text(selectedWall.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColors.accentRed)

                        Text("Cada anaquel contiene 10 bandejas y cada bandeja muestra 10 slots numerados.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }

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
                wallButton(for: walls[0], index: 0, tall: true)
                wallButton(for: walls[1], index: 1, tall: false)
                wallButton(for: walls[2], index: 2, tall: true)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.backgroundWhite,
                            Color.white
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 96)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .font(.title2)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("Zona central de surtido")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
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

                            Text("10 bandejas")
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
        let shelf = selectedWall.shelves[selectedShelfIndex]

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(shelf.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("\(selectedWall.name) • 10 bandejas")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                Label("100 slots", systemImage: "number.square.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AppColors.accentRed.opacity(0.12))
                    )
            }

            LazyVStack(spacing: 14) {
                ForEach(shelf.trays) { tray in
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

    private func wallButton(for wall: StorageWall, index: Int, tall: Bool) -> some View {
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

    private func trayCard(for tray: StorageTray) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tray.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.primaryBlue)

                Spacer()

                Text("Slots 1-10")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(tray.slots) { slot in
                    VStack(spacing: 4) {
                        Text("\(slot.number)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.accentRed)

                        Text("Slot")
                            .font(.caption2)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.backgroundWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
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
}

private struct StorageWall: Identifiable {
    let id = UUID()
    let name: String
    let shelves: [StorageShelf]

    static let sampleWalls: [StorageWall] = [
        StorageWall(name: "Pared izquierda", shelves: StorageShelf.makeShelves(prefix: "A")),
        StorageWall(name: "Pared frontal", shelves: StorageShelf.makeShelves(prefix: "B")),
        StorageWall(name: "Pared derecha", shelves: StorageShelf.makeShelves(prefix: "C"))
    ]
}

private struct StorageShelf: Identifiable {
    let id = UUID()
    let name: String
    let trays: [StorageTray]

    static func makeShelves(prefix: String) -> [StorageShelf] {
        (1...4).map { shelfNumber in
            StorageShelf(
                name: "Anaquel \(prefix)\(shelfNumber)",
                trays: StorageTray.makeTrays()
            )
        }
    }
}

private struct StorageTray: Identifiable {
    let id = UUID()
    let name: String
    let slots: [StorageSlot]

    static func makeTrays() -> [StorageTray] {
        (1...10).map { trayNumber in
            StorageTray(
                name: "Bandeja \(trayNumber)",
                slots: (1...10).map(StorageSlot.init(number:))
            )
        }
    }
}

private struct StorageSlot: Identifiable {
    let id = UUID()
    let number: Int
}
