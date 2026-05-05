import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    var titleColor: Color = AppColors.primaryBlue
    var subtitleColor: Color = AppColors.secondaryText


    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)
                .padding(.horizontal, 15)

            Text(subtitle)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(subtitleColor)
                .padding(.horizontal, 15)
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .accessibilityAddTraits(.isHeader)
    }
}
#Preview {
    ContentView()
}
