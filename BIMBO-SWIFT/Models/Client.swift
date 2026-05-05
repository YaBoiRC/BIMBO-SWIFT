import CoreLocation
import Foundation

struct Client: Identifiable {
    let id: String
    let name: String
    let categoryPurchaseHistory: [CategoryPurchaseHistory]
    let orderHistory: [Order]

    var weeklyPurchaseAverage: Double {
        categoryPurchaseHistory.reduce(0) { $0 + $1.currentWeeklyAverage }
    }

    // Reliability is based on the stability of total weekly demand
    // across all categories using the coefficient of variation.
    var rating: Int {
        let totals = aggregatedWeeklyOrders
        guard let mean = totals.nonEmptyMean, mean > 0 else { return 1 }

        let variance = totals.reduce(0.0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(totals.count)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = standardDeviation / mean
        let boundedScore = max(0.0, min(1.0, 1.0 - coefficientOfVariation))

        return max(1, min(5, Int(round(1 + (boundedScore * 4)))))
    }

    var reliabilityIndex: Double {
        let totals = aggregatedWeeklyOrders
        guard let mean = totals.nonEmptyMean, mean > 0 else { return 0 }

        let variance = totals.reduce(0.0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(totals.count)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = standardDeviation / mean

        return max(0.0, min(1.0, 1.0 - coefficientOfVariation))
    }

    private var aggregatedWeeklyOrders: [Double] {
        let longestHistory = categoryPurchaseHistory.map { $0.weeklyOrders.count }.max() ?? 0
        guard longestHistory > 0 else { return [] }

        return (0..<longestHistory).map { weekIndex in
            categoryPurchaseHistory.reduce(0.0) { partial, history in
                guard history.weeklyOrders.indices.contains(weekIndex) else { return partial }
                return partial + history.weeklyOrders[weekIndex]
            }
        }
    }
    
    let categories: [String]
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
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

private extension Array where Element == Double {
    var nonEmptyMean: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
