import SwiftUI

struct RatingStarsView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .foregroundStyle(index < rating ? AppColors.accentRed : AppColors.cardBorder)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating \(rating) out of 5 stars")
    }
}
