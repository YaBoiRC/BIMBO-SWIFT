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
                    
                    
                    
                    MapSectionView()
                        .padding(.horizontal, -20)
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        SummaryMetricCardView(
                            title: "Active clients",
                            value: "\(clients.count)",
                            systemImage: "person.3.fill"
                        )
                        SummaryMetricCardView(
                            title: "Weekly average units",
                            value: "\(Int(totalWeeklyUnits.rounded())) units",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    }.frame(maxWidth: .infinity, alignment: .center)
                    
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        SummaryMetricCardView(
                            title: "Average rating",
                            value: String(format: "%.1f / 5", averageRating),
                            systemImage: "star.fill"
                        )

                        SummaryMetricCardView(
                            title: "Tracked categories",
                            value: "\(topCategoryCount)",
                            systemImage: "shippingbox.fill"
                        )
                    }.frame(maxWidth: .infinity, alignment: .center)
                    

                        
                    
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Dashboard", systemImage: "square.grid.2x2")
        }
    }
}
#Preview {
    ContentView()
}
