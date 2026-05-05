import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeaderView(
                        title: "Settings",
                        subtitle: "Placeholder configuration content for future app options."
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Display")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryBlue)

                        Text("This screen can host user preferences, filters, and account options.")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Settings", systemImage: "gearshape.fill")
        }
    }
}
