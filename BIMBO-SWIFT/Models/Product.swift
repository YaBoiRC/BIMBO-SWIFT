import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let price: Double
    let weightGrams: Double
}
