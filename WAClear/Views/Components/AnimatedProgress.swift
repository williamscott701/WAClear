import SwiftUI

/// Circular progress ring shown during video processing.
struct AnimatedProgress: View {
    let progress: Double   // 0...1
    let lineWidth: CGFloat
    let diameter: CGFloat

    init(progress: Double, diameter: CGFloat = 200, lineWidth: CGFloat = 12) {
        self.progress = progress
        self.diameter = diameter
        self.lineWidth = lineWidth
    }

    private var gradientColors: [Color] {
        [Color(red: 0.58, green: 0.20, blue: 1.0), Color(red: 0.20, green: 0.50, blue: 1.0)]
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: diameter * 0.18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
        AnimatedProgress(progress: 0.65)
    }
}
