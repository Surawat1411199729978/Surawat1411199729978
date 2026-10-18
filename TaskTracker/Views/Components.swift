import SwiftUI

enum Palette {
    static let colors: [Color] = [.blue, .pink, .indigo, .green, .orange, .purple, .teal, .red, .brown, .mint]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

struct AvatarView: View {
    let name: String
    let colorIndex: Int
    var size: CGFloat = 28

    var body: some View {
        let color = Palette.color(colorIndex)
        Text(name.first.map { String($0).uppercased() } ?? "?")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: Circle())
    }
}

struct StatusPill: View {
    let status: TaskStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

/// Coloured header + big number card, like the summary row on the desktop design.
struct StatusSummaryCard: View {
    let status: TaskStatus
    let count: Int
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(status.title, systemImage: status.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(status.color.opacity(0.14))
            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? status.color : .clear, lineWidth: 2)
        }
    }
}

struct FilterChip<MenuContent: View>: View {
    let title: String
    let isActive: Bool
    @ViewBuilder let content: () -> MenuContent

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .background(isActive ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
    }
}

struct CardContainer<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let systemImage {
                Label(title, systemImage: systemImage).font(.headline)
            } else {
                Text(title).font(.headline)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ColorDotPicker: View {
    @Binding var selection: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(Palette.colors.indices, id: \.self) { index in
                Circle()
                    .fill(Palette.color(index))
                    .frame(width: 32, height: 32)
                    .overlay {
                        if index == selection {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selection = index }
            }
        }
        .padding(.vertical, 4)
    }
}

extension String {
    /// A URL for non-empty strings, adding https:// when the scheme is missing.
    var asWebURL: URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") { return URL(string: trimmed) }
        return URL(string: "https://" + trimmed)
    }
}
