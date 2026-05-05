import Foundation

struct Client: Identifiable {
    let id: String
    let name: String
    let weeklyPurchaseAverage: Double
    let rating: Int
    let categories: [String]
}
