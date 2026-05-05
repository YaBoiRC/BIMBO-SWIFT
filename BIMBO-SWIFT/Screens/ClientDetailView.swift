import SwiftUI

struct ClientDetailView: View {
    let client: Client

    private let predictor = ClientOrderPredictor()

    private var predictions: [CategoryPrediction] {
        predictor.predictions(for: client)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeaderView(
                    title: client.name,
                    subtitle: "Client ID \(client.id) con prediccion de la proxima semana por categoria."
                )

                ClientCardView(client: client)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Prediccion de la proxima semana por categoria")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)

                    Text("Los valores mostrados usan tu modelo de Core ML y, si no hay una prediccion valida, se usa una estimacion de respaldo basada en el historial reciente.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }

                ForEach(predictions) { prediction in
                    PredictionInsightCardView(prediction: prediction)
                }
            }
            .padding(20)
        }
        .background(AppColors.backgroundWhite.ignoresSafeArea())
        .navigationTitle("Client Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
