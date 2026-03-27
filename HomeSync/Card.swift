//
//  Card.swift
//  HomeSync
//
//  Created by Samarth Bhate on 3/25/26.
//

import SwiftUI

struct Card<SheetContent: View>: View {
    let symbol: String
    let systemName: String
    let name: String
    let sends: String
    @Binding var isActivated: Bool
    var callback: (() -> Void)?
    var onContextButtonTap: (() -> Void)?

    private let sheetContent: SheetContent?

    @State private var showSheet = false

    @Environment(\.isEnabled) private var isEnabled
    @EnvironmentObject private var bleManager: BLEManager

    init(
        symbol: String,
        systemName: String,
        name: String,
        sends: String,
        isActivated: Binding<Bool>,
        callback: (() -> Void)? = nil,
        onContextButtonTap: (() -> Void)? = nil
    ) where SheetContent == EmptyView {
        self.symbol = symbol
        self.systemName = systemName
        self.name = name
        self.sends = sends
        self._isActivated = isActivated
        self.callback = callback
        self.onContextButtonTap = onContextButtonTap
        self.sheetContent = nil
    }

    init(
        symbol: String,
        systemName: String,
        name: String,
        sends: String,
        isActivated: Binding<Bool>,
        callback: (() -> Void)? = nil,
        onContextButtonTap: (() -> Void)? = nil,
        @ViewBuilder sheetContent: () -> SheetContent
    ) {
        self.symbol = symbol
        self.systemName = systemName
        self.name = name
        self.sends = sends
        self._isActivated = isActivated
        self.callback = callback
        self.onContextButtonTap = onContextButtonTap
        self.sheetContent = sheetContent()
    }

    private var accentColor: Color {
        isEnabled ? (isActivated ? .yellow : .white) : .white.opacity(0.75)
    }

    private var iconBackground: some ShapeStyle {
        isActivated ? AnyShapeStyle(.yellow.opacity(0.18)) : AnyShapeStyle(.white.opacity(0.08))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accentColor.opacity(isActivated ? 0.9 : 0.35), lineWidth: 2)
                }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Text(symbol)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())

                    Spacer()

                        
                }

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(iconBackground)
                            .overlay {
                                Circle()
                                    .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
                            }
                            .frame(width: 68, height: 68)

                        Image(systemName: systemName)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(isEnabled ? accentColor : .red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(isEnabled ? (isActivated ? "Enabled" : "Disabled") : "Unavailable")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)

            if sheetContent != nil {
                Button {
                    onContextButtonTap?()
                    showSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(14)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .opacity(isEnabled ? 1 : 0.72)
        .onTapGesture {
            guard isEnabled else { return }
            isActivated.toggle()
            bleManager.send(data: "\(sends)\r\n")
            callback?()
        }
        .sheet(isPresented: $showSheet) {
            if let sheetContent {
                sheetContent
            }
        }
    }
}

#Preview {
    @Previewable @State var isActivated = false

    ZStack {
        LinearGradient(
            colors: [Color(red: 0, green: 3 / 255, blue: 1), Color(red: 69 / 255, green: 233 / 255, blue: 1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        Card(
            symbol: "LIGHT",
            systemName: "lightbulb",
            name: "Living Room",
            sends: "0",
            isActivated: $isActivated
        )
        .padding()
    }
    .environmentObject(BLEManager())
}
