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
            categories: [categories[0], categories[1], categories[3]]
        ),
        Client(
            id: "CL-1002",
            name: "Sunrise Grocery",
            weeklyPurchaseAverage: 980,
            rating: 5,
            categories: [categories[0], categories[2]]
        ),
        Client(
            id: "CL-1003",
            name: "Central Deli",
            weeklyPurchaseAverage: 715,
            rating: 3,
            categories: [categories[1], categories[3]]
        ),
        Client(
            id: "CL-1004",
            name: "Northside Foods",
            weeklyPurchaseAverage: 1560,
            rating: 5,
            categories: categories
        )
    ]
}
