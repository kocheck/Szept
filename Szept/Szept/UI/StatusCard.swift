import SwiftUI

struct StatusCard: View {
    let mode: SzeptMode
    let description: String

    var body: some View {
        Text(description)
            .padding(8)
    }
}
