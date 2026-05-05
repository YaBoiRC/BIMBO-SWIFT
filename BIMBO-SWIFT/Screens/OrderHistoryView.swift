import SwiftUI

struct OrderHistoryView: View {
    let client: Client

    var body: some View {
        ScrollView {
            if client.orderHistory.isEmpty {
                Text("No order history found for this client.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 20) {
                    ForEach(client.orderHistory) { order in
                        orderCard(order)
                    }
                }
                .padding(20)
            }
        }
        .background(AppColors.backgroundWhite.ignoresSafeArea())
    }

    private func orderCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header: ref + date + status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ref. \(order.id)")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(order.date, style: .date)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)
                }
                Spacer()
                statusBadge(order.status)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider().overlay(AppColors.cardBorder.opacity(0.8))

            // Column headers
            HStack(spacing: 0) {
                Text("Product")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Price")
                    .frame(width: 76, alignment: .trailing)
                Text("Qty")
                    .frame(width: 36, alignment: .trailing)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppColors.secondaryText)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(AppColors.backgroundWhite)

            Divider().overlay(AppColors.cardBorder.opacity(0.5))

            // Item rows
            ForEach(order.items) { item in
                HStack(spacing: 0) {
                    Text(item.product.name)
                        .font(.caption)
                        .foregroundStyle(AppColors.primaryBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.product.price, format: .currency(code: "MXN"))
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: 76, alignment: .trailing)
                    Text("\(item.quantity)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.primaryBlue)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                Divider()
                    .overlay(AppColors.cardBorder.opacity(0.4))
                    .padding(.leading, 18)
            }

            // Summary footer
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Weight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)
                    Spacer()
                    Text(String(format: "%.1f kg", order.totalWeightKg))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)
                }
                Divider().overlay(AppColors.cardBorder.opacity(0.6))
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.primaryBlue)
                    Spacer()
                    Text(order.totalAmount, format: .currency(code: "MXN"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.accentRed)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .shadow(color: AppColors.primaryBlue.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private func statusBadge(_ status: OrderStatus) -> some View {
        let color: Color = status == .delivered ? .green : (status == .pending ? .orange : .red)
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}
