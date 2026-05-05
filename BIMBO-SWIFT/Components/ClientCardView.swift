import SwiftUI

struct ClientCardView: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(client.name)
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("Client ID: \(client.id)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                RatingStarsView(rating: client.rating)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Average weekly purchases")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)

                Text(client.weeklyPurchaseAverage, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.accentRed)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Categories")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)

                FlexibleTagListView(items: client.categories)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppColors.primaryBlue.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}
