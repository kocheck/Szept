import SwiftUI

struct AudioMeter: View {
    let level: Float

    var body: some View {
        Rectangle()
            .fill(.green)
            .frame(height: 8)
    }
}
