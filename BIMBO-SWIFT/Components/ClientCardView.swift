import SwiftUI

struct ClientCardView: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KEY ACCOUNT")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(AppColors.secondaryText)

                    Text(client.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)
                        .multilineTextAlignment(.leading)

                    Text("Client ID: \(client.id)")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("Health")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)

                    RatingStarsView(rating: client.rating)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.backgroundWhite)
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                metricPanel

                Divider()
                    .overlay(AppColors.cardBorder.opacity(0.9))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Categories")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)

                    FlexibleTagListView(items: client.categories)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.primaryBlue.opacity(0.18),
                            AppColors.primaryBlue.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6)
                .padding(.vertical, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: AppColors.primaryBlue.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var metricPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average weekly units")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(client.weeklyPurchaseAverage.rounded()))")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.accentRed)

                Text("units")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Text("Current average demand across this account.")
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.backgroundWhite)
        )
    }
}
