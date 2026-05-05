import SwiftUI

struct CategoryTagView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.primaryBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.primaryBlue.opacity(0.12))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Category \(title)")
    }
}
