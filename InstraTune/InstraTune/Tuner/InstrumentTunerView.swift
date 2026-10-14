import SwiftUI

/// Instrument tuner: pick an instrument, then tap a string on the drawing to
/// hear its pitch. The sounding string glows.
struct InstrumentTunerView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer
    let a4: Double

    @AppStorage("tuner.instrument") private var instrumentID: String = Instrument.guitar.id
    @State private var showPicker = false
    @State private var activeStringID: Int?

    private var instrument: Instrument {
        Instrument.all.first { $0.id == instrumentID } ?? .guitar
    }

    private var activeString: InstrumentString? {
        instrument.strings.first { $0.id == activeStringID }
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: instrument.symbol)
                        .font(.title2)
                        .foregroundStyle(Theme.honeydew)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instrument.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.honeydew)
                        Text(instrument.tuningDescription)
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.silver)
                    }
                    Spacer()
                    Text("Change")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.honeydew)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.silver)
                }
                .card()
            }
            .buttonStyle(.plain)

            InstrumentDiagram(instrument: instrument, activeStringID: activeStringID) { string in
                toggle(string)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if let string = activeString {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.inTune)
                    Text("\(string.note.label) · \(String(format: "%.2f Hz", string.note.frequency(a4: a4)))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.honeydew)
                    Spacer()
                    Button("Stop") { stop() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.honeydew)
                } else {
                    Image(systemName: "hand.tap").foregroundStyle(Theme.silver)
                    Text("Tap a string to hear its pitch")
                        .font(.subheadline)
                        .foregroundStyle(Theme.silver)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.charcoal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .sheet(isPresented: $showPicker) {
            InstrumentPickerSheet(selectionID: $instrumentID)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: instrumentID) { _, _ in stop() }
        .onChange(of: a4) { _, newValue in
            if let string = activeString {
                tonePlayer.play(note: string.note, a4: newValue)
            }
        }
        .onDisappear { stop() }
    }

    private func toggle(_ string: InstrumentString) {
        if activeStringID == string.id {
            stop()
        } else {
            activeStringID = string.id
            tonePlayer.play(note: string.note, a4: a4)
        }
    }

    private func stop() {
        activeStringID = nil
        tonePlayer.stop()
    }
}

// MARK: - Picker

struct InstrumentPickerSheet: View {
    @Binding var selectionID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Instrument.all) { instrument in
                    Button {
                        selectionID = instrument.id
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: instrument.symbol)
                                .font(.title3)
                                .foregroundStyle(Theme.honeydew)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(instrument.name)
                                    .foregroundStyle(Theme.honeydew)
                                Text(instrument.tuningDescription)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Theme.silver)
                            }
                            Spacer()
                            if instrument.id == selectionID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.inTune)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.charcoal)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.prussian.ignoresSafeArea())
            .navigationTitle("Instrument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.honeydew)
                }
            }
        }
    }
}

// MARK: - Diagram

/// Geometry shared between the artwork and the tappable string overlays.
struct DiagramLayout {
    let size: CGSize
    let instrument: Instrument

    let pegSize: CGFloat = 40
    let pegTop: CGFloat = 4
    var stringTop: CGFloat { pegTop + pegSize }
    var bridgeY: CGFloat { size.height - 34 }
    var stringLength: CGFloat { max(10, bridgeY - stringTop) }
    var stringCount: Int { instrument.strings.count }
    var stringSpacing: CGFloat { min(52, size.width * 0.52 / CGFloat(stringCount)) }
    var neckWidth: CGFloat { stringSpacing * CGFloat(stringCount) + 14 }
    var headstockBottom: CGFloat { stringTop + size.height * 0.1 }
    var bodyTop: CGFloat { size.height * instrument.bodyStart }
    var bodyWidth: CGFloat { size.width * instrument.bodyWidth }

    func x(forStringIndex index: Int) -> CGFloat {
        let left = size.width / 2 - stringSpacing * CGFloat(stringCount) / 2
        return left + stringSpacing * (CGFloat(index) + 0.5)
    }
}

struct InstrumentDiagram: View {
    let instrument: Instrument
    let activeStringID: Int?
    let onTap: (InstrumentString) -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = DiagramLayout(size: geo.size, instrument: instrument)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    InstrumentArtwork.draw(layout: layout, in: &context)
                }
                .allowsHitTesting(false)

                ForEach(Array(instrument.strings.enumerated()), id: \.element.id) { index, string in
                    let isActive = string.id == activeStringID
                    Button {
                        onTap(string)
                    } label: {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(isActive ? Theme.spruce : Theme.charcoal)
                                    .overlay(Circle().stroke(isActive ? Theme.honeydew : Theme.silver.opacity(0.5),
                                                             lineWidth: 1.5))
                                Text(string.note.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(isActive ? Theme.honeydew : Theme.silver)
                            }
                            .frame(width: layout.pegSize, height: layout.pegSize)

                            Rectangle()
                                .fill(isActive ? Theme.honeydew : Theme.silver.opacity(0.85))
                                .frame(width: string.gauge, height: layout.stringLength)
                                .shadow(color: isActive ? Theme.honeydew.opacity(0.9) : .clear, radius: 7)
                        }
                        .frame(width: layout.stringSpacing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: layout.x(forStringIndex: index),
                              y: layout.pegTop + (layout.pegSize + layout.stringLength) / 2)
                    .animation(.easeOut(duration: 0.15), value: isActive)
                    .accessibilityLabel("\(string.note.label) string")
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
        }
    }
}

/// Draws a stylised instrument body behind the strings.
enum InstrumentArtwork {
    static func draw(layout: DiagramLayout, in context: inout GraphicsContext) {
        let w = layout.size.width
        let h = layout.size.height
        let centerX = w / 2
        let body = GraphicsContext.Shading.color(Theme.charcoal)
        let outline = GraphicsContext.Shading.color(Theme.silver.opacity(0.35))
        let background = GraphicsContext.Shading.color(Theme.prussian)

        // Headstock (or scroll) behind the pegs.
        switch layout.instrument.family {
        case .guitarLike:
            let head = CGRect(x: centerX - layout.neckWidth / 2 - 10,
                              y: layout.pegTop + layout.pegSize * 0.5,
                              width: layout.neckWidth + 20,
                              height: layout.headstockBottom - layout.pegTop - layout.pegSize * 0.5)
            let headPath = Path(roundedRect: head, cornerRadius: 12)
            context.fill(headPath, with: body)
            context.stroke(headPath, with: outline, lineWidth: 1)
        case .violinLike:
            let scroll = Path(ellipseIn: CGRect(x: centerX - layout.neckWidth / 2 - 8,
                                                y: layout.pegTop + layout.pegSize * 0.4,
                                                width: layout.neckWidth + 16,
                                                height: layout.headstockBottom - layout.pegTop - layout.pegSize * 0.4))
            context.fill(scroll, with: body)
            context.stroke(scroll, with: outline, lineWidth: 1)
        }

        // Neck.
        let neck = CGRect(x: centerX - layout.neckWidth / 2,
                          y: layout.headstockBottom - 4,
                          width: layout.neckWidth,
                          height: layout.bodyTop - layout.headstockBottom + 24)
        let neckPath = Path(roundedRect: neck, cornerRadius: 6)
        context.fill(neckPath, with: GraphicsContext.Shading.color(Theme.charcoal.opacity(0.85)))
        context.stroke(neckPath, with: outline, lineWidth: 1)

        // Frets / fingerboard lines.
        let fretCount = 7
        for i in 1...fretCount {
            let y = layout.headstockBottom + (layout.bodyTop - layout.headstockBottom) * CGFloat(i) / CGFloat(fretCount + 1)
            var fret = Path()
            fret.move(to: CGPoint(x: neck.minX + 3, y: y))
            fret.addLine(to: CGPoint(x: neck.maxX - 3, y: y))
            context.stroke(fret, with: outline, lineWidth: 1)
        }

        // Body.
        let bodyBottom = h - 6
        let bodyHeight = bodyBottom - layout.bodyTop
        let upperWidth = layout.bodyWidth * (layout.instrument.family == .violinLike ? 0.78 : 0.84)
        let upper = Path(ellipseIn: CGRect(x: centerX - upperWidth / 2,
                                           y: layout.bodyTop,
                                           width: upperWidth,
                                           height: bodyHeight * 0.55))
        let lower = Path(ellipseIn: CGRect(x: centerX - layout.bodyWidth / 2,
                                           y: layout.bodyTop + bodyHeight * 0.3,
                                           width: layout.bodyWidth,
                                           height: bodyHeight * 0.7))
        context.fill(upper, with: body)
        context.fill(lower, with: body)
        context.stroke(upper, with: outline, lineWidth: 1)
        context.stroke(lower, with: outline, lineWidth: 1)

        switch layout.instrument.family {
        case .guitarLike:
            // Round sound hole.
            let radius = layout.bodyWidth * 0.13
            let hole = Path(ellipseIn: CGRect(x: centerX - radius,
                                              y: layout.bodyTop + bodyHeight * 0.3 - radius,
                                              width: radius * 2, height: radius * 2))
            context.fill(hole, with: background)
            context.stroke(hole, with: outline, lineWidth: 2)
        case .violinLike:
            // C-bouts: cut the waist with background-coloured circles.
            let waistY = layout.bodyTop + bodyHeight * 0.42
            let cut = layout.bodyWidth * 0.2
            for side: CGFloat in [-1, 1] {
                let cx = centerX + side * (layout.bodyWidth * 0.5)
                let circle = Path(ellipseIn: CGRect(x: cx - cut, y: waistY - cut * 0.9, width: cut * 2, height: cut * 1.8))
                context.fill(circle, with: background)
            }
            // f-holes.
            for side: CGFloat in [-1, 1] {
                let fx = centerX + side * layout.bodyWidth * 0.2
                var f = Path()
                f.move(to: CGPoint(x: fx - 4 * side, y: waistY - bodyHeight * 0.08))
                f.addCurve(to: CGPoint(x: fx + 4 * side, y: waistY + bodyHeight * 0.14),
                           control1: CGPoint(x: fx + 10 * side, y: waistY - bodyHeight * 0.02),
                           control2: CGPoint(x: fx - 10 * side, y: waistY + bodyHeight * 0.08))
                context.stroke(f, with: background, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }

        // Bridge.
        let bridge = CGRect(x: centerX - layout.neckWidth * 0.65,
                            y: layout.bridgeY - 3,
                            width: layout.neckWidth * 1.3,
                            height: 8)
        context.fill(Path(roundedRect: bridge, cornerRadius: 3),
                     with: GraphicsContext.Shading.color(Theme.silver.opacity(0.7)))
    }
}
