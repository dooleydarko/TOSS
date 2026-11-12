import SwiftUI
import UIKit

enum TossDesign {
    static let canvas = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.047, green: 0.055, blue: 0.063, alpha: 1) : UIColor(red: 0.949, green: 0.957, blue: 0.953, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.094, green: 0.106, blue: 0.118, alpha: 1) : .white
    })
    static let border = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.19, green: 0.22, blue: 0.24, alpha: 1) : UIColor(red: 0.86, green: 0.89, blue: 0.88, alpha: 1)
    })
    static let tint = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.737, green: 0.91, blue: 0.855, alpha: 1) : UIColor(red: 0.09, green: 0.36, blue: 0.29, alpha: 1)
    })
    static let primaryForeground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.09, green: 0.137, blue: 0.129, alpha: 1) : .white
    })
    static let ink = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .white : UIColor(red: 0.09, green: 0.137, blue: 0.129, alpha: 1)
    })
    static let accent = Color(red: 0.737, green: 0.91, blue: 0.855)
    static let action = Color(red: 0.09, green: 0.137, blue: 0.129)
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 16
}

struct TossCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TossDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: TossDesign.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: TossDesign.cardRadius).strokeBorder(TossDesign.border, lineWidth: 1))
    }
}

struct TossPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundColor(enabled ? TossDesign.primaryForeground : .secondary)
            .background(enabled ? (scheme == .dark ? TossDesign.accent : TossDesign.action) : TossDesign.border)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .clipShape(RoundedRectangle(cornerRadius: TossDesign.controlRadius))
    }
}

struct TossRecordingOrb: View {
    let recording: Bool
    let busy: Bool
    let processing: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                // Leave imported component geometry and motion intact while recording.
                if (recording || processing) && !reduceMotion {
                    PulsingOrb(size: 90)
                } else {
                    Circle()
                        .fill(RadialGradient(colors: [.white, Color.blue.opacity(0.9), .purple],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 4, endRadius: 63))
                        .frame(width: 90, height: 90)
                }
                if processing || (busy && !recording) {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.55), radius: 2)
                }
            }
            .frame(width: 150, height: 150)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(processing || (busy && !recording))
        .accessibilityLabel(recording ? "Stop recording" : "Start recording")
        .accessibilityValue(processing ? "Creating handoff" : recording ? "Recording" : busy ? "Preparing" : "Ready")
    }
}
