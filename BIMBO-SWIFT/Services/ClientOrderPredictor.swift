import CoreML
import Foundation
import OSLog

// Coordinates category-level forecasting for the client detail screen.
struct ClientOrderPredictor {
    // Loads and queries the bundled Core ML model when available.
    private let modelLoader = OrderPredictionModelLoader()
    // Emits runtime diagnostics for model loading and prediction attempts.
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BIMBO-SWIFT",
        category: "ClientOrderPredictor"
    )

    // Builds one prediction object per category and sorts the strongest demand first.
    func predictions(for client: Client) -> [CategoryPrediction] {
        client.categoryPurchaseHistory.map { history in
            let forecast = forecastNextOrder(
                for: history.categoryName,
                using: history.weeklyOrders
            )
            let currentAverage = history.currentWeeklyAverage
            let trendDelta = forecast - currentAverage

            return CategoryPrediction(
                categoryName: history.categoryName,
                predictedNextOrder: forecast,
                currentAverage: currentAverage,
                trendDelta: trendDelta
            )
        }
        .sorted { $0.predictedNextOrder > $1.predictedNextOrder }
    }

    // Uses the ML model first and falls back to a local estimate if inference fails.
    private func forecastNextOrder(for category: String, using values: [Double]) -> Double {
        if let modelForecast = modelLoader.predictNextWeek(
            category: category,
            weeklyOrders: values
        ) {
            logger.info("Core ML prediction succeeded for category: \(category, privacy: .public)")
            return max(modelForecast, 0)
        }

        logger.error("Core ML prediction unavailable for category: \(category, privacy: .public). Falling back to heuristic forecast.")

        guard !values.isEmpty else { return 0 }
        guard values.count > 1 else { return values[0] }

        let weightedAverage = normalizedWeightedAverage(values)
        let momentum = recentMomentum(values)
        let forecast = weightedAverage + momentum

        return max(forecast, 0)
    }

    // Gives more importance to the most recent weeks in the historical series.
    private func normalizedWeightedAverage(_ values: [Double]) -> Double {
        let weightedValues = values.enumerated().map { index, value in
            value * Double(index + 1)
        }
        let weightTotal = Double((1...values.count).reduce(0, +))

        return weightedValues.reduce(0, +) / weightTotal
    }

    // Measures short-term acceleration using only the latest observations.
    private func recentMomentum(_ values: [Double]) -> Double {
        let recentWindow = Array(values.suffix(3))
        guard recentWindow.count > 1 else { return 0 }

        let deltas = zip(recentWindow.dropFirst(), recentWindow).map(-)
        return deltas.reduce(0, +) / Double(deltas.count)
    }
}

// Wraps the raw Core ML interaction so the view layer never deals with model details.
private struct OrderPredictionModelLoader {
    // Input feature name used by the tabular model for the product category.
    private let categoryFeatureName = "Categoria"
    // Base name of the compiled model bundled by Xcode.
    private let modelName = "OrderPredict2"
    // Emits detailed model loading and inference diagnostics.
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BIMBO-SWIFT",
        category: "OrderPredictionModelLoader"
    )

    // Runs inference for one category using the model's declared input/output schema.
    func predictNextWeek(category: String, weeklyOrders: [Double]) -> Double? {
        guard let model = loadModel() else { return nil }

        do {
            // Read the model schema dynamically so this code does not depend on generated wrappers.
            let inputDescriptions = model.modelDescription.inputDescriptionsByName
            let weekFeatureNames = inputDescriptions.keys
                .filter { $0.hasPrefix("Cantidad_Semana_") }
                .sorted(by: compareWeekFeatureNames)

            guard !weekFeatureNames.isEmpty else { return nil }

            // Fit the app's history to the exact amount of week features expected by the model.
            let normalizedValues = normalizedWeeklyOrders(
                weeklyOrders,
                requiredCount: weekFeatureNames.count
            )

            var features: [String: MLFeatureValue] = [:]

            // Populate each numerical week input in order.
            for (featureName, value) in zip(weekFeatureNames, normalizedValues) {
                features[featureName] = MLFeatureValue(double: value)
            }

            if let categoryDescription = inputDescriptions[categoryFeatureName] {
                // Map the app's category label to the compact label used when training the model.
                let normalizedCategory = normalizedCategoryName(category)
                let categoryValue = featureValue(
                    for: normalizedCategory,
                    description: categoryDescription
                )
                features[categoryFeatureName] = categoryValue
            }

            let inputProvider = try MLDictionaryFeatureProvider(dictionary: features)
            let prediction = try model.prediction(from: inputProvider)

            // Return the first numeric output exposed by the model description.
            for outputName in model.modelDescription.outputDescriptionsByName.keys.sorted() {
                if let value = numericValue(from: prediction.featureValue(for: outputName)) {
                    logger.info("Core ML output read from feature: \(outputName, privacy: .public)")
                    return value
                }
            }
        } catch {
            logger.error("Core ML prediction failed for category \(category, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }

        logger.error("Core ML prediction returned no numeric outputs for category: \(category, privacy: .public)")
        return nil
    }

    // Loads the compiled model generated by Xcode into memory.
    private func loadModel() -> MLModel? {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            logger.error("Core ML model bundle not found: \(modelName, privacy: .public).mlmodelc")
            return nil
        }

        do {
            let model = try MLModel(contentsOf: modelURL)
            logger.info("Core ML model loaded successfully from bundle: \(modelName, privacy: .public)")
            return model
        } catch {
            logger.error("Core ML model failed to load: \(modelName, privacy: .public). Error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // Truncates or pads history so the feature vector always matches the model contract.
    private func normalizedWeeklyOrders(_ values: [Double], requiredCount: Int) -> [Double] {
        guard requiredCount > 0 else { return [] }
        guard !values.isEmpty else { return Array(repeating: 0, count: requiredCount) }

        if values.count >= requiredCount {
            // Keep the most recent values when the history is longer than the model input.
            return Array(values.suffix(requiredCount))
        }

        // Left-pad with the oldest known value to preserve the short trend shape.
        let padding = Array(repeating: values.first ?? 0, count: requiredCount - values.count)
        return padding + values
    }

    // Orders feature names like Cantidad_Semana_1, Cantidad_Semana_2, etc.
    private func compareWeekFeatureNames(_ lhs: String, _ rhs: String) -> Bool {
        weekIndex(from: lhs) < weekIndex(from: rhs)
    }

    // Extracts the trailing week number from the feature name.
    private func weekIndex(from featureName: String) -> Int {
        Int(featureName.split(separator: "_").last ?? "") ?? 0
    }

    // Creates a typed Core ML feature value that matches the declared category input type.
    private func featureValue(
        for category: String,
        description: MLFeatureDescription
    ) -> MLFeatureValue {
        switch description.type {
        case .string:
            return MLFeatureValue(string: category)
        case .int64:
            return MLFeatureValue(int64: Int64(category) ?? 0)
        case .double:
            return MLFeatureValue(double: Double(category) ?? 0)
        default:
            return MLFeatureValue(string: category)
        }
    }

    // Normalizes verbose UI category names to the shorter training labels used by the model.
    private func normalizedCategoryName(_ category: String) -> String {
        let normalized = category.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if normalized.contains("bollos") {
            return "Bollos"
        }

        if normalized.contains("botanas") {
            return "Botanas"
        }

        if normalized.contains("galletas") {
            return "Galletas"
        }

        if normalized.contains("pan de caja") {
            return "Pan de caja"
        }

        return category
    }

    // Converts different Core ML numeric output types into a plain Double for the UI.
    private func numericValue(from featureValue: MLFeatureValue?) -> Double? {
        guard let featureValue else { return nil }

        switch featureValue.type {
        case .double:
            return featureValue.doubleValue
        case .int64:
            return Double(featureValue.int64Value)
        case .multiArray:
            if let multiArray = featureValue.multiArrayValue, multiArray.count > 0 {
                // Some regressors expose scalar outputs as a single-value MLMultiArray.
                return multiArray[0].doubleValue
            }
            return nil
        default:
            return nil
        }
    }
}
