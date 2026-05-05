import SwiftUI

struct ContentView: View {
    private let clients = ClientRepository.sampleClients

    var body: some View {
        TabView {
            DashboardView(clients: clients)
            ClientsListView(clients: clients)
            SurtidoView()
            CategoriesView(categories: ClientRepository.categories)
            SettingsView()
        }
        .tint(AppColors.primaryBlue)
    }
}

#Preview {
    ContentView()
}
