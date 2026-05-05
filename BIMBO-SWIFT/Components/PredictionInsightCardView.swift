import SwiftUI

struct PredictionInsightCardView: View {
    let prediction: CategoryPrediction

    private var trendColor: Color {
        prediction.trendDelta >= 0 ? AppColors.primaryBlue : AppColors.accentRed
    }

    private var trendLabel: String {
        prediction.trendDelta >= 0 ? "Growing demand" : "Softening demand"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prediction.categoryName)
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            HStack {
                metricBlock(
                    title: "Current average",
                    value: "\(Int(prediction.currentAverage.rounded())) units"
                )

                Spacer()

                metricBlock(
                    title: "Next predicted order",
                    value: "\(Int(prediction.predictedNextOrder.rounded())) units"
                )
            }

            HStack(spacing: 10) {
                Image(systemName: prediction.trendDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(trendColor)

                Text("\(trendLabel): \(Int(abs(prediction.trendDelta).rounded())) units")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trendColor)
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
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.accentRed)
        }
    }
}
