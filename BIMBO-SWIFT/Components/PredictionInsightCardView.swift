import SwiftUI

struct PredictionInsightCardView: View {
    let prediction: CategoryPrediction

    private var trendColor: Color {
        prediction.trendDelta >= 0 ? AppColors.primaryBlue : AppColors.accentRed
    }

    private var trendLabel: String {
        prediction.trendDelta >= 0 ? "Demanda en aumento" : "Demanda a la baja"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prediction.categoryName)
                .font(.headline)
                .foregroundStyle(AppColors.primaryBlue)

            HStack {
                metricBlock(
                    title: "Promedio actual",
                    value: "\(Int(prediction.currentAverage.rounded())) unidades"
                )

                Spacer()

                metricBlock(
                    title: "Siguiente pedido previsto",
                    value: "\(Int(prediction.predictedNextOrder.rounded())) unidades"
                )
            }

            HStack(spacing: 10) {
                Image(systemName: prediction.trendDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(trendColor)

                Text("\(trendLabel): \(Int(abs(prediction.trendDelta).rounded())) unidades")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prediction.categoryName)
        .accessibilityValue(accessibilitySummary)
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

    private var accessibilitySummary: String {
        "\(trendLabel). Promedio actual \(Int(prediction.currentAverage.rounded())) unidades. Siguiente pedido previsto \(Int(prediction.predictedNextOrder.rounded())) unidades. Variacion de tendencia \(Int(abs(prediction.trendDelta).rounded())) unidades."
    }
}
