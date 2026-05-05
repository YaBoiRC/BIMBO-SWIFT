import Foundation

struct Order: Identifiable {
    let id: String
    let date: Date
    let items: [OrderItem]
    let status: OrderStatus

    var totalAmount: Double {
        items.reduce(0) { $0 + $1.subtotal }
    }

    var totalWeightKg: Double {
        items.reduce(0) { $0 + $1.product.weightGrams * Double($1.quantity) } / 1000.0
    }
}

struct OrderItem: Identifiable {
    let id: String
    let product: Product
    let quantity: Int

    var subtotal: Double { product.price * Double(quantity) }
}

enum OrderStatus: String {
    case delivered = "Delivered"
    case pending = "Pending"
    case cancelled = "Cancelled"
}
