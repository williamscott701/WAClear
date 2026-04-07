import SwiftUI

/// Small upsell badge shown on chunk cards for free users.
struct WatermarkBadge: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text("Remove Watermark")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.58, green: 0.20, blue: 1.0), Color(red: 0.85, green: 0.25, blue: 0.60)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WatermarkBadge {}
    }
}
