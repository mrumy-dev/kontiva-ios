import SwiftUI

/// The bundled local profile pictures (Kontiva-branded avatar tiles), loaded from
/// the asset catalog by name.
enum ProfileIcons {
    static let all: [String] = [
        "human-01-charcoal", "human-02-warm", "human-03-outline", "human-04-soft-square",
        "human-05-arc", "human-06-offset", "human-07-quiet", "human-08-premium",
        "household-01-couple", "household-02-family", "household-03-home", "household-04-shared",
        "monogram-01-a", "monogram-02-m", "monogram-03-r", "monogram-04-s",
    ]
}

/// Renders the chosen profile picture, or a neutral placeholder when none is set.
struct ProfileAvatar: View {
    let name: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let name {
                Image(name).resizable().interpolation(.high)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(KontivaTheme.charcoal)
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.46))
                        .foregroundStyle(KontivaTheme.offWhite.opacity(0.9))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A grid sheet to pick a bundled profile picture (or none).
struct AvatarPickerSheet: View {
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: KontivaTheme.Space.md), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: KontivaTheme.Space.md) {
                    ForEach(ProfileIcons.all, id: \.self) { name in
                        Button { selected = name; dismiss() } label: {
                            ProfileAvatar(name: name, size: 68)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 68 * 0.24, style: .continuous)
                                        .strokeBorder(selected == name ? KontivaTheme.accent : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(KontivaTheme.Space.md)
            }
            .navigationTitle(loc(.profileChoosePicture))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc(.commonCancel)) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc(.profileNoPicture)) { selected = nil; dismiss() }
                }
            }
        }
    }
}
