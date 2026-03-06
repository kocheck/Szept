import SwiftUI

struct AppWarningBanner: View {
    let reason: String

    var body: some View {
        Label(reason, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.orange)
    }
}
