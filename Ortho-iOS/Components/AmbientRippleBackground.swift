import SwiftUI

/// Ambient background effect: concentric stroke rings expanding from a
/// single origin, with a soft lens-flare halo at the origin point. Rings
/// fade as they grow; flare is a static radial gradient.
///
/// Implemented with `TimelineView(.animation)` + `Canvas` so the per-frame
/// math runs once and renders all rings in a single GPU-friendly pass.
/// Decorative only — tap-through, hidden from VoiceOver.
struct AmbientRippleBackground: View {
    /// Where ripples emanate from, as a fraction of the view's size.
    var origin: UnitPoint = UnitPoint(x: 0.5, y: 0.4)
    /// Absolute point-space nudge applied on top of `origin`. Useful when
    /// the visual target is a known offset from a layout anchor (e.g.
    /// "the first letter of the centered wordmark," which is a fixed
    /// number of points left of the wordmark's center regardless of
    /// screen width).
    var originOffset: CGSize = .zero
    /// Stroke color of the rings. View applies its own opacity ramp.
    var rippleColor: Color = .black
    /// Base color of the radial flare halo. View applies its own opacity ramp.
    var flareColor: Color = .white

    // MARK: - Tuning constants

    /// Number of concurrent rings on screen.
    private let count: Int = 4
    /// Seconds for one ring to grow from origin to the view's far corner.
    private let period: Double = 7.5
    /// Peak ring-stroke opacity, fades to zero as the ring expands.
    private let peakOpacity: Double = 0.18
    /// Stroke width of each ring in points.
    private let lineWidth: CGFloat = 1.25
    /// Radius of the lens-flare halo in points. Bigger = softer glow.
    private let flareRadius: CGFloat = 270
    /// Peak alpha of the flare's center stop.
    private let flarePeakOpacity: Double = 0.23

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let center = CGPoint(
                    x: size.width * origin.x + originOffset.width,
                    y: size.height * origin.y + originOffset.height
                )
                let maxRadius = hypot(
                    max(center.x, size.width - center.x),
                    max(center.y, size.height - center.y)
                )

                drawFlare(in: canvas, center: center)

                for i in 0..<count {
                    let phaseOffset = Double(i) / Double(count)
                    let phase = ((elapsed / period) + phaseOffset)
                        .truncatingRemainder(dividingBy: 1.0)
                    let radius = maxRadius * phase
                    let opacity = peakOpacity * (1.0 - phase)
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    canvas.stroke(
                        Path(ellipseIn: rect),
                        with: .color(rippleColor.opacity(opacity)),
                        lineWidth: lineWidth
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Drawing helpers

    /// Lens-flare halo: bright at the origin, fading to clear at
    /// `flareRadius`. Three-stop gradient gives a non-linear falloff that
    /// reads as a soft bloom rather than a hard disc.
    private func drawFlare(in canvas: GraphicsContext, center: CGPoint) {
        let rect = CGRect(
            x: center.x - flareRadius,
            y: center.y - flareRadius,
            width: flareRadius * 2,
            height: flareRadius * 2
        )
        canvas.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: flareColor.opacity(flarePeakOpacity), location: 0),
                    .init(color: flareColor.opacity(0.02),             location: 0.45),
                    .init(color: flareColor.opacity(0),                location: 1.0),
                ]),
                center: center,
                startRadius: 0,
                endRadius: flareRadius
            )
        )
    }
}

#Preview("Ripple · Light") {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        AmbientRippleBackground(
            rippleColor: AppTheme.accent,
            flareColor:  AppTheme.accent
        )
        .ignoresSafeArea()
        Text("ORTHO")
            .font(.system(size: 28, weight: .regular))
            .tracking(8)
            .foregroundStyle(AppTheme.text)
    }
}

#Preview("Ripple · Dark") {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        AmbientRippleBackground(
            rippleColor: AppTheme.accent,
            flareColor:  AppTheme.accent
        )
        .ignoresSafeArea()
        Text("ORTHO")
            .font(.system(size: 28, weight: .regular))
            .tracking(8)
            .foregroundStyle(AppTheme.text)
    }
    .preferredColorScheme(.dark)
}
