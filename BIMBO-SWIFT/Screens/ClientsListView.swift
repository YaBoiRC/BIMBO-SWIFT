import SwiftUI

struct ClientsListView: View {
    let clients: [Client]

    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 520), spacing: 20, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeaderView(
                        title: "Clients",
                        subtitle: "Weekly purchase insights for key customer accounts."
                    )

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(clients) { client in
                            ClientCardView(client: client)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Client List")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Clients", systemImage: "list.bullet.rectangle")
        }
    }
}
