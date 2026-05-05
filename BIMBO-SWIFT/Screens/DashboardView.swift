import SwiftUI
import MapKit

struct DashboardView: View {
    let clients: [Client]

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

                    
                    MapSectionView(clients: clients)
                        .padding(.horizontal, -20)
                    
                    dashboardMetricsPanel
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
    var dashboardMetricsPanel: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.98, blue: 1.0),
                            Color(red: 0.92, green: 0.96, blue: 0.99),
                            Color(red: 0.98, green: 0.95, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(AppColors.primaryBlue.opacity(0.12))
                .frame(width: 220, height: 220)
                .offset(x: 170, y: -90)

            Circle()
                .fill(AppColors.accentRed.opacity(0.08))
                .frame(width: 180, height: 180)
                .offset(x: -50, y: 150)

            VStack(alignment: .leading, spacing: 18) {
                Text("Resumen operativo")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.primaryBlue)

                Text("Panorama rapido de clientes, volumen semanal, confiabilidad y categorias monitoreadas.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)

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
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppColors.cardBorder.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: AppColors.primaryBlue.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

#Preview {
    ContentView()
}
