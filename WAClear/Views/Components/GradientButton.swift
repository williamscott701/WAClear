import SwiftUI

struct GradientButton: View {
    let title: String
    let systemImage: String?
    let action: () async -> Void

    @State private var isPressed = false

    init(_ title: String, systemImage: String? = nil, action: @escaping () async -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.58, green: 0.20, blue: 1.0), Color(red: 0.20, green: 0.50, blue: 1.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
        }
        .buttonStyle(PressedButtonStyle(isPressed: $isPressed))
    }
}

private struct PressedButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                isPressed = pressed
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GradientButton("Select Video", systemImage: "video.badge.plus") {}
            .padding()
    }
}
