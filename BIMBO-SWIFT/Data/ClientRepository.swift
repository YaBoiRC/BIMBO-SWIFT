import Foundation

enum ClientRepository {
    static let categories = [
        "Pan de caja fresco y congelado",
        "Bollos, English muffins y bagels",
        "Botanas saladas",
        "Galletas"
    ]

    static let sampleClients: [Client] = [
        Client(
            id: "CL-1001",
            name: "Lopez Market",
            weeklyPurchaseAverage: 1240,
            rating: 4,
            categories: [categories[0], categories[1], categories[3]],
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[0], weeklyOrders: [320, 340, 355, 372, 390, 402]),
                CategoryPurchaseHistory(categoryName: categories[1], weeklyOrders: [180, 195, 188, 205, 214, 220]),
                CategoryPurchaseHistory(categoryName: categories[3], weeklyOrders: [140, 150, 160, 158, 172, 180])
            ]
        ),
        Client(
            id: "CL-1002",
            name: "Sunrise Grocery",
            weeklyPurchaseAverage: 980,
            rating: 5,
            categories: [categories[0], categories[2]],
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[0], weeklyOrders: [260, 272, 268, 280, 289, 300]),
                CategoryPurchaseHistory(categoryName: categories[2], weeklyOrders: [120, 132, 140, 144, 150, 158])
            ]
        ),
        Client(
            id: "CL-1003",
            name: "Central Deli",
            weeklyPurchaseAverage: 715,
            rating: 3,
            categories: [categories[1], categories[3]],
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[1], weeklyOrders: [150, 148, 152, 158, 164, 170]),
                CategoryPurchaseHistory(categoryName: categories[3], weeklyOrders: [90, 94, 98, 104, 100, 108])
            ]
        ),
        Client(
            id: "CL-1004",
            name: "Northside Foods",
            weeklyPurchaseAverage: 1560,
            rating: 5,
            categories: categories,
            categoryPurchaseHistory: [
                CategoryPurchaseHistory(categoryName: categories[0], weeklyOrders: [380, 400, 415, 430, 450, 470]),
                CategoryPurchaseHistory(categoryName: categories[1], weeklyOrders: [210, 225, 232, 240, 250, 262]),
                CategoryPurchaseHistory(categoryName: categories[2], weeklyOrders: [170, 176, 182, 190, 201, 214]),
                CategoryPurchaseHistory(categoryName: categories[3], weeklyOrders: [160, 168, 172, 180, 188, 196])
            ]
        )
    ]
}
