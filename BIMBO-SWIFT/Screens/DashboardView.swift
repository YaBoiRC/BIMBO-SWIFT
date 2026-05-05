import SwiftUI
import MapKit

struct DashboardView: View {
    let clients: [Client]
    @State private var showsMetricsPanel = true

    private var totalWeeklyUnits: Double {
        clients.reduce(0) { $0 + $1.weeklyPurchaseAverage }
    }

    private var averageRating: Double {
        guard !clients.isEmpty else { return 0 }
        return Double(clients.reduce(0) { $0 + $1.rating }) / Double(clients.count)
    }

    private var topCategoryCount: Int {
        Set(clients.flatMap(\.categories)).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    SectionHeaderView(
                        title: "Bienvenido",
                        subtitle: "Trazando tu ruta de reparto actual..."
                    )

                    
                    mapSection

                    if showsMetricsPanel {
                        dashboardMetricsPanel
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Inicio", systemImage: "square.grid.2x2")
        }
    }
}

private extension DashboardView {
    var mapSectionHeight: CGFloat {
        showsMetricsPanel ? 300 : 560
    }

    var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            MapSectionView(clients: clients, mapHeight: mapSectionHeight)
                .padding(.horizontal, -20)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    showsMetricsPanel.toggle()
                }
            } label: {
                Label(
                    showsMetricsPanel ? "Ocultar resumen" : "Mostrar resumen",
                    systemImage: showsMetricsPanel ? "chevron.down.circle.fill" : "chevron.up.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.96))
                )
                .overlay(
                    Capsule()
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .shadow(color: AppColors.primaryBlue.opacity(0.08), radius: 12, x: 0, y: 6)
            }
            .padding(.trailing, 10)
            .padding(.bottom, 12)
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: showsMetricsPanel)
    }

    var dashboardMetricsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resumen operativo")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("Consulta rapidamente clientes activos, volumen semanal, confiabilidad y cobertura de categorias.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                Text("Actual")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.primaryBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.primaryBlue.opacity(0.08))
                    )
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                SummaryMetricCardView(
                    title: "Clientes activos",
                    value: "\(clients.count)",
                    systemImage: "person.3.fill"
                )
                SummaryMetricCardView(
                    title: "Promedio semanal",
                    value: "\(Int(totalWeeklyUnits.rounded())) unidades",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                SummaryMetricCardView(
                    title: "Confiabilidad promedio",
                    value: String(format: "%.1f / 5", averageRating),
                    systemImage: "star.fill"
                )
                SummaryMetricCardView(
                    title: "Categorias monitoreadas",
                    value: "\(topCategoryCount)",
                    systemImage: "shippingbox.fill"
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .shadow(color: AppColors.primaryBlue.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

#Preview {
    ContentView()
}
