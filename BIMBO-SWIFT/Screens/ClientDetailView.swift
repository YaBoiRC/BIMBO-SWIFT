import SwiftUI

struct ClientDetailView: View {
    let client: Client

    @State private var selectedTab = 0
    private let predictor = ClientOrderPredictor()

    private var predictions: [CategoryPrediction] {
        predictor.predictions(for: client)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Predicciones").tag(0)
                Text("Historial").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.backgroundWhite)

            if selectedTab == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeaderView(
                            title: client.name,
                            subtitle: "ID cliente \(client.id) con prediccion de la proxima semana por categoria."
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
            } else {
                OrderHistoryView(client: client)
            }
        }
        .background(AppColors.backgroundWhite.ignoresSafeArea())
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
