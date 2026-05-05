import Foundation

struct Client: Identifiable {
    let id: String
    let name: String
    let weeklyPurchaseAverage: Double
    let rating: Int
    let categories: [String]
    let categoryPurchaseHistory: [CategoryPurchaseHistory]
}

struct CategoryPurchaseHistory: Identifiable {
    let id = UUID()
    let categoryName: String
    let weeklyOrders: [Double]

    var currentWeeklyAverage: Double {
        guard !weeklyOrders.isEmpty else { return 0 }
        return weeklyOrders.reduce(0, +) / Double(weeklyOrders.count)
    }
}

struct CategoryPrediction: Identifiable {
    let id = UUID()
    let categoryName: String
    let predictedNextOrder: Double
    let currentAverage: Double
    let trendDelta: Double
}
