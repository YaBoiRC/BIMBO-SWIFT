import SwiftUI

struct FlexibleTagListView: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    CategoryTagView(title: item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    CategoryTagView(title: item)
                }
            }
        }
    }
}
