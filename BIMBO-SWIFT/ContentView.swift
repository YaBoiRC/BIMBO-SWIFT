import SwiftUI

struct ContentView: View {
    private let clients = ClientRepository.sampleClients

    var body: some View {
        TabView {
            DashboardView(clients: clients)
            ClientsListView(clients: clients)
            SurtidoView()
            CargamentoView()
            SettingsView()
        }
        .tint(AppColors.primaryBlue)
    }
}

#Preview {
    ContentView()
}
