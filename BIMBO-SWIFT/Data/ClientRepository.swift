import Foundation

enum ClientRepository {
    
    // MARK: - Date Helper
    /// Utilizes native Foundation APIs to calculate dates efficiently.
    private static func date(daysAgo: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }
    
    // MARK: - Mock Products
    private static let panBlanco = Product(id: "P-001", name: "Pan Blanco Grande", category: "Pan de caja fresco y congelado", price: 45.0, weightGrams: 680.0)
    private static let panIntegral = Product(id: "P-002", name: "Pan Integral", category: "Pan de caja fresco y congelado", price: 50.0, weightGrams: 680.0)
    private static let bollosBimbo = Product(id: "P-003", name: "Bollos Clasicos", category: "Bollos, English muffins y bagels", price: 40.0, weightGrams: 400.0)
    private static let englishMuffins = Product(id: "P-004", name: "English Muffins", category: "Bollos, English muffins y bagels", price: 55.0, weightGrams: 350.0)
    private static let gamesa = Product(id: "P-005", name: "Galletas Avena", category: "Galletas", price: 35.0, weightGrams: 260.0)
    private static let emperador = Product(id: "P-006", name: "Emperador", category: "Galletas", price: 38.0, weightGrams: 280.0)

    // MARK: - Categories
    static let categories = [
        "Pan de caja fresco y congelado",
        "Bollos, English muffins y bagels",
        "Botanas saladas",
        "Galletas"
    ]

    // MARK: - Sample Data
    static let sampleClients: [Client] = [
        Client(
            id: "CL-1001",
            name: "Lopez Market",
            rating: 4,
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[0], weeklyOrders: [320, 340, 355, 372, 390, 402]),
                CategoryPurchaseHistory(categoryName: categories[1], weeklyOrders: [180, 195, 188, 205, 214, 220]),
                CategoryPurchaseHistory(categoryName: categories[3], weeklyOrders: [140, 150, 160, 158, 172, 180])
            ],
            orderHistory: [
                Order(id: "ORD-1001-01", date: date(daysAgo: 21), items: [
                    OrderItem(id: "OI-1-1", product: panBlanco,   quantity: 10),
                    OrderItem(id: "OI-1-2", product: panIntegral, quantity: 8),
                    OrderItem(id: "OI-1-3", product: bollosBimbo, quantity: 6),
                    OrderItem(id: "OI-1-4", product: gamesa,      quantity: 5)
                ], status: .delivered),
                Order(id: "ORD-1001-02", date: date(daysAgo: 14), items: [
                    OrderItem(id: "OI-2-1", product: panBlanco,   quantity: 12),
                    OrderItem(id: "OI-2-2", product: panIntegral, quantity: 6),
                    OrderItem(id: "OI-2-3", product: bollosBimbo, quantity: 4),
                    OrderItem(id: "OI-2-4", product: gamesa,      quantity: 8),
                    OrderItem(id: "OI-2-5", product: emperador,   quantity: 3)
                ], status: .delivered),
                Order(id: "ORD-1001-03", date: date(daysAgo: 7), items: [
                    OrderItem(id: "OI-3-1", product: panBlanco,      quantity: 10),
                    OrderItem(id: "OI-3-2", product: panIntegral,    quantity: 10),
                    OrderItem(id: "OI-3-3", product: englishMuffins, quantity: 5),
                    OrderItem(id: "OI-3-4", product: gamesa,         quantity: 6)
                ], status: .pending)
            ],
            categories: [categories[0], categories[1], categories[3]]
        ),
        Client(
            id: "CL-1002",
            name: "Sunrise Grocery",
            rating: 5,
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[0], weeklyOrders: [260, 272, 268, 280, 289, 300]),
                CategoryPurchaseHistory(categoryName: categories[2], weeklyOrders: [120, 132, 140, 144, 150, 158])
            ],
            orderHistory: [],
            categories: [categories[0], categories[2]]
        ),
        Client(
            id: "CL-1003",
            name: "Central Deli",
            rating: 3,
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[1], weeklyOrders: [150, 148, 152, 158, 164, 170]),
                CategoryPurchaseHistory(categoryName: categories[3], weeklyOrders: [90, 94, 98, 104, 100, 108])
            ],
            orderHistory: [],
            categories: [categories[1], categories[3]]
        ),
        Client(
            id: "CL-1004",
            name: "Northside Foods",
            rating: 5,
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[0], weeklyOrders: [380, 400, 415, 430, 450, 470]),
                CategoryPurchaseHistory(categoryName: categories[1], weeklyOrders: [210, 225, 232, 240, 250, 262]),
                CategoryPurchaseHistory(categoryName: categories[2], weeklyOrders: [170, 176, 182, 190, 201, 214]),
                CategoryPurchaseHistory(categoryName: categories[3], weeklyOrders: [160, 168, 172, 180, 188, 196])
            ],
            orderHistory: [],
            categories: categories
        )
    ]
}
