import SwiftUI

struct CategoriesView: View {
    let categories: [String]

    var body: some View {
        NavigationStack {
            List {
                Section("Product Categories") {
                    ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(.headline)
                                .foregroundStyle(AppColors.accentRed)

                            Text(category)
                                .foregroundStyle(AppColors.primaryBlue)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundWhite)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label("Categories", systemImage: "tag.fill")
        }
    }
}
