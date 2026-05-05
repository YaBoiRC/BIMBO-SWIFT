import Foundation

struct Client: Identifiable {
    let id: String
    let name: String
    let rating: Int
    let categoryPurchaseHistory: [CategoryPurchaseHistory]
    let orderHistory: [Order]

    var weeklyPurchaseAverage: Double {
        categoryPurchaseHistory.reduce(0) { $0 + $1.currentWeeklyAverage }
    }
    
    let categories: [String]
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
