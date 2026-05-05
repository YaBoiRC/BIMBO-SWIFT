import SwiftUI

struct ClientsListView: View {
    let clients: [Client]

    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 520), spacing: 24, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SectionHeaderView(
                        title: "Clientes",
                        subtitle: "Resumen semanal de compra para cuentas clave."
                    )

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(clients) { client in
                            NavigationLink {
                                ClientDetailView(client: client)
                            } label: {
                                ClientCardView(client: client)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Lista de clientes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Clientes", systemImage: "list.bullet.rectangle")
        }
    }
}
