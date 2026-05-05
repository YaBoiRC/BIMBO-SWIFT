import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeaderView(
                        title: "Configuracion",
                        subtitle: "Contenido de configuracion provisional para opciones futuras."
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Pantalla")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("Esta pantalla puede incluir preferencias del usuario, filtros y opciones de cuenta.")
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(20)
            }
            .background(AppColors.backgroundWhite.ignoresSafeArea())
            .navigationTitle("Configuracion")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Configuracion", systemImage: "gearshape.fill")
        }
    }
}
