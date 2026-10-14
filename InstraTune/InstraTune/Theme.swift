import SwiftUI

extension Color {
    /// Builds a color from a 24-bit hex value such as 0x011638.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// The app palette.
enum Theme {
    static let prussian = Color(hex: 0x011638)   // Prussian Blue – app background
    static let charcoal = Color(hex: 0x364156)   // Charcoal Blue – cards & controls
    static let silver   = Color(hex: 0xCDCDCD)   // Silver – secondary text
    static let honeydew = Color(hex: 0xDFF8EB)   // Honeydew – primary text / highlights
    static let spruce   = Color(hex: 0x214E34)   // Dark Spruce – primary action colour

    /// A brighter tint of Dark Spruce used for the "in tune" state so it reads
    /// clearly against the dark background.
    static let inTune   = Color(hex: 0x3FB168)
}

// MARK: - Reusable styling

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    /// Charcoal rounded card used throughout the app.
    func card() -> some View { modifier(CardModifier()) }
}

/// Small circular icon button (used for BPM ± and similar).
struct RoundIconButton: View {
    let systemImage: String
    let action: () -> Void

    init(_ systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.honeydew)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.prussian))
        }
        .buttonStyle(.plain)
    }
}

/// A button showing a setting's title and current value; opens a pop-up menu.
struct SettingButton: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.silver)
                HStack {
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.honeydew)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.silver)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
