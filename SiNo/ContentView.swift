import SwiftUI
import UIKit

struct Preset: Identifiable, Equatable {
    let id: String
    let positive: String
    let negative: String
    let positiveColor: Color
    let negativeColor: Color
    let fontSize: CGFloat
    var isCustom: Bool = false
}

let builtInPresets: [Preset] = [
    Preset(id: "sino", positive: "SÌ", negative: "NO",
           positiveColor: Color(red: 0.2, green: 0.8, blue: 0.4),
           negativeColor: Color(red: 0.9, green: 0.25, blue: 0.3),
           fontSize: 140),
    Preset(id: "yesno", positive: "YES", negative: "NO",
           positiveColor: Color(red: 0.3, green: 0.7, blue: 1.0),
           negativeColor: Color(red: 1.0, green: 0.4, blue: 0.2),
           fontSize: 120),
    Preset(id: "gono", positive: "GO", negative: "NAH",
           positiveColor: Color(red: 0.0, green: 0.9, blue: 0.6),
           negativeColor: Color(red: 0.6, green: 0.3, blue: 0.9),
           fontSize: 130),
    Preset(id: "daimai", positive: "DAI", negative: "MAI",
           positiveColor: Color(red: 1.0, green: 0.8, blue: 0.0),
           negativeColor: Color(red: 0.5, green: 0.5, blue: 0.55),
           fontSize: 130),
    Preset(id: "fallo", positive: "FALLO", negative: "FUGGI",
           positiveColor: Color(red: 0.2, green: 0.8, blue: 0.4),
           negativeColor: Color(red: 0.9, green: 0.1, blue: 0.1),
           fontSize: 100),
]

enum SwipeAxis {
    case horizontal
    case vertical
}

struct ContentView: View {
    @AppStorage("hasSeenCoachMark") private var hasSeenCoachMark = false
    @AppStorage("selectedPreset") private var selectedPresetId = "sino"
    @AppStorage("customPositive") private var customPositive = ""
    @AppStorage("customNegative") private var customNegative = ""

    // Stats
    @AppStorage("totalSpins") private var totalSpins = 0
    @AppStorage("positiveCount") private var positiveCount = 0
    @AppStorage("negativeCount") private var negativeCount = 0
    @AppStorage("totalFlips") private var totalFlips = 0

    @State private var angle: Double = 0
    @State private var velocity: Double = 0
    @State private var isSpinning = false
    @State private var isDragging = false
    @State private var dragStartAngle: Double = 0
    @State private var currentAxis: SwipeAxis = .horizontal
    @State private var displayLink: CADisplayLink?
    @State private var lastTimestamp: CFTimeInterval = 0
    @State private var lastFace: Bool = true

    @State private var showResult = false
    @State private var resultIsPositive = true
    @State private var spinFlipCount = 0
    @State private var textScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 0
    @State private var bgFlash: Double = 0

    @State private var showCoachMark = false
    @State private var handOffset: CGFloat = -60
    @State private var handOpacity: Double = 0

    @State private var showCustomSheet = false
    @State private var showStatsSheet = false
    @State private var editPositive = ""
    @State private var editNegative = ""

    // Physics
    private let coulombFriction: Double = 30
    private let viscousFriction: Double = 0.8
    private let stopThreshold: Double = 12.0
    private let minSpinVelocity: Double = 150
    private let dragScale: Double = 0.9

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)

    var preset: Preset {
        if selectedPresetId == "custom" && !customPositive.isEmpty && !customNegative.isEmpty {
            let maxLen = max(customPositive.count, customNegative.count)
            let size: CGFloat = maxLen <= 2 ? 140 : maxLen <= 4 ? 110 : maxLen <= 6 ? 85 : 65
            return Preset(id: "custom",
                          positive: customPositive.uppercased(),
                          negative: customNegative.uppercased(),
                          positiveColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                          negativeColor: Color(red: 0.9, green: 0.25, blue: 0.3),
                          fontSize: size, isCustom: true)
        }
        return builtInPresets.first { $0.id == selectedPresetId } ?? builtInPresets[0]
    }

    var showingPositive: Bool {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let a = normalized < 0 ? normalized + 360 : normalized
        return a < 90 || a >= 270
    }

    var resultColor: Color { resultIsPositive ? preset.positiveColor : preset.negativeColor }

    var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        currentAxis == .horizontal ? (x: 0, y: 1, z: 0) : (x: 1, y: 0, z: 0)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [resultColor.opacity(bgFlash * 0.4), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            ZStack {
                if showingPositive {
                    Text(preset.positive)
                        .font(.system(size: preset.fontSize, weight: .black, design: .rounded))
                        .foregroundColor(preset.positiveColor)
                        .shadow(color: preset.positiveColor.opacity(showResult ? 0.8 : 0.4), radius: showResult ? glowRadius : 10)
                } else {
                    Text(preset.negative)
                        .font(.system(size: preset.fontSize, weight: .black, design: .rounded))
                        .foregroundColor(preset.negativeColor)
                        .scaleEffect(x: currentAxis == .horizontal ? -1 : 1,
                                     y: currentAxis == .vertical ? -1 : 1)
                        .shadow(color: preset.negativeColor.opacity(showResult ? 0.8 : 0.4), radius: showResult ? glowRadius : 10)
                }
            }
            .rotation3DEffect(.degrees(angle), axis: rotationAxis, perspective: 0.3)
            .scaleEffect(textScale)


            // Menu overlay
            VStack {
                HStack {
                    Spacer()
                    Menu {
                        ForEach(builtInPresets) { p in
                            Button {
                                selectedPresetId = p.id
                                resetState()
                            } label: {
                                HStack {
                                    Text("\(p.positive) / \(p.negative)")
                                    if p.id == selectedPresetId { Image(systemName: "checkmark") }
                                }
                            }
                        }

                        Divider()

                        Button {
                            editPositive = customPositive
                            editNegative = customNegative
                            showCustomSheet = true
                        } label: {
                            HStack {
                                Text("Personalizza...")
                                if selectedPresetId == "custom" { Image(systemName: "checkmark") }
                            }
                        }

                        Divider()

                        Button { showStatsSheet = true } label: {
                            Label("Statistiche", systemImage: "chart.bar")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 8)
                Spacer()
            }

            // Coach mark
            if showCoachMark {
                VStack {
                    Spacer()
                    Image(systemName: "hand.draw")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(x: handOffset)
                        .opacity(handOpacity)
                        .padding(.bottom, 120)
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if !hasSeenCoachMark {
                showCoachMark = true
                startCoachMarkAnimation()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !isSpinning else { return }

                    if !isDragging {
                        isDragging = true
                        dragStartAngle = angle
                        showResult = false
                        bgFlash = 0
                        glowRadius = 0
                        textScale = 1.0
                        dismissCoachMark()

                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        currentAxis = dy > dx ? .vertical : .horizontal
                    }

                    let drag = currentAxis == .horizontal
                        ? value.translation.width
                        : -value.translation.height
                    angle = dragStartAngle + drag * dragScale
                }
                .onEnded { value in
                    guard !isSpinning else { return }
                    isDragging = false
                    let gestureVelocity: Double
                    if currentAxis == .horizontal {
                        gestureVelocity = value.velocity.width * dragScale
                    } else {
                        gestureVelocity = -value.velocity.height * dragScale
                    }

                    if abs(gestureVelocity) < minSpinVelocity {
                        snapToNearestFace()
                        // Record even slow snaps
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            recordResult(positive: showingPositive)
                        }
                    } else {
                        velocity = gestureVelocity
                        haptic.prepare()
                        heavyHaptic.prepare()
                        lastFace = showingPositive
                        spinFlipCount = 0
                        isSpinning = true
                        startDisplayLink()
                    }
                }
        )
        .onDisappear { stopDisplayLink() }
        .sheet(isPresented: $showCustomSheet) {
            CustomPresetSheet(
                positive: $editPositive,
                negative: $editNegative,
                onSave: {
                    customPositive = editPositive.trimmingCharacters(in: .whitespaces)
                    customNegative = editNegative.trimmingCharacters(in: .whitespaces)
                    selectedPresetId = "custom"
                    resetState()
                    showCustomSheet = false
                }
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStatsSheet) {
            StatsSheet(
                totalSpins: totalSpins,
                positiveCount: positiveCount,
                negativeCount: negativeCount,
                totalFlips: totalFlips,
                positiveColor: preset.positiveColor,
                negativeColor: preset.negativeColor,
                positiveLabel: preset.positive,
                negativeLabel: preset.negative,
                onReset: {
                    totalSpins = 0
                    positiveCount = 0
                    negativeCount = 0
                    totalFlips = 0
                }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
    }

    func resetState() {
        angle = 0
        showResult = false
        bgFlash = 0
        glowRadius = 0
    }

    func recordResult(positive: Bool) {
        totalSpins += 1
        totalFlips += spinFlipCount
        if positive { positiveCount += 1 }
        else { negativeCount += 1 }
    }

    // MARK: - Coach mark

    func startCoachMarkAnimation() {
        guard showCoachMark else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard showCoachMark else { return }
            handOffset = -60
            withAnimation(.easeIn(duration: 0.4)) { handOpacity = 1 }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard showCoachMark else { return }
                withAnimation(.easeInOut(duration: 0.8)) { handOffset = 60 }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard showCoachMark else { return }
                    withAnimation(.easeOut(duration: 0.3)) { handOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        startCoachMarkAnimation()
                    }
                }
            }
        }
    }

    func dismissCoachMark() {
        guard showCoachMark else { return }
        hasSeenCoachMark = true
        withAnimation(.easeOut(duration: 0.2)) { handOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showCoachMark = false }
    }

    // MARK: - Physics

    func snapToNearestFace() {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let a = normalized < 0 ? normalized + 360 : normalized

        let targetAngle: Double
        if a < 90 { targetAngle = angle - a }
        else if a < 270 { targetAngle = angle + (180 - a) }
        else { targetAngle = angle + (360 - a) }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { angle = targetAngle }
    }

    func startDisplayLink() {
        let link = CADisplayLink(target: DisplayLinkTarget { ts in
            self.tick(timestamp: ts)
        }, selector: #selector(DisplayLinkTarget.step))
        link.add(to: .main, forMode: .common)
        lastTimestamp = 0
        displayLink = link
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func revealResult() {
        resultIsPositive = showingPositive
        showResult = true
        recordResult(positive: showingPositive)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { textScale = 1.2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { textScale = 1.0 }
        }

        withAnimation(.easeOut(duration: 0.2)) { glowRadius = 40 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 1.0)) { glowRadius = 15 }
        }

        withAnimation(.easeOut(duration: 0.15)) { bgFlash = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 1.2)) { bgFlash = 0 }
        }
    }

    func tick(timestamp: CFTimeInterval) {
        if lastTimestamp == 0 { lastTimestamp = timestamp; return }

        let dt = min(timestamp - lastTimestamp, 1.0 / 30.0)
        lastTimestamp = timestamp

        let speed = abs(velocity)
        let totalFriction = coulombFriction + viscousFriction * speed
        let deceleration = totalFriction * (velocity > 0 ? -1.0 : 1.0)

        velocity += deceleration * dt
        angle += velocity * dt

        let currentFace = showingPositive
        if currentFace != lastFace {
            lastFace = currentFace
            spinFlipCount += 1
            if speed > 100 { haptic.impactOccurred(intensity: min(speed / 800, 1.0)) }
        }

        if abs(velocity) < stopThreshold || (velocity > 0) != (velocity + deceleration * dt > 0) {
            stopDisplayLink()
            isSpinning = false
            heavyHaptic.impactOccurred()

            let normalized = angle.truncatingRemainder(dividingBy: 360)
            let a = normalized < 0 ? normalized + 360 : normalized

            let targetAngle: Double
            if a < 90 { targetAngle = angle - a }
            else if a < 270 { targetAngle = angle + (180 - a) }
            else { targetAngle = angle + (360 - a) }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { angle = targetAngle }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { revealResult() }
        }
    }
}

// MARK: - Stats Sheet

struct StatsSheet: View {
    let totalSpins: Int
    let positiveCount: Int
    let negativeCount: Int
    let totalFlips: Int
    let positiveColor: Color
    let negativeColor: Color
    let positiveLabel: String
    let negativeLabel: String
    let onReset: () -> Void

    private var positiveRatio: CGFloat {
        guard totalSpins > 0 else { return 0.5 }
        return CGFloat(positiveCount) / CGFloat(totalSpins)
    }

    private var negativeRatio: CGFloat {
        guard totalSpins > 0 else { return 0.5 }
        return CGFloat(negativeCount) / CGFloat(totalSpins)
    }

    private var avgFlips: Double {
        guard totalSpins > 0 else { return 0 }
        return Double(totalFlips) / Double(totalSpins)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Statistiche")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.top, 20)

            // Numbers row
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(totalSpins)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("spin")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(totalFlips)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("giri")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", avgFlips))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("media")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            if totalSpins > 0 {
                // Bar
                VStack(spacing: 12) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(positiveColor)
                                .frame(width: max(geo.size.width * positiveRatio, 4))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(negativeColor)
                                .frame(width: max(geo.size.width * negativeRatio, 4))
                        }
                    }
                    .frame(height: 32)
                    .padding(.horizontal, 24)

                    // Labels
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(positiveLabel)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(positiveColor)
                            Text("\(positiveCount) (\(Int(positiveRatio * 100))%)")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(negativeLabel)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(negativeColor)
                            Text("\(negativeCount) (\(Int(negativeRatio * 100))%)")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            if totalSpins > 0 {
                Button(role: .destructive) {
                    onReset()
                } label: {
                    Text("Azzera")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.red.opacity(0.7))
                }
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Custom Preset Sheet

struct CustomPresetSheet: View {
    @Binding var positive: String
    @Binding var negative: String
    let onSave: () -> Void

    var isValid: Bool {
        !positive.trimmingCharacters(in: .whitespaces).isEmpty &&
        !negative.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Personalizza")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.top, 20)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Positivo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("SÌ", text: $positive)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Negativo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("NO", text: $negative)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                }
            }
            .padding(.horizontal, 24)

            Button {
                onSave()
            } label: {
                Text("Salva")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(isValid ? .blue : .gray))
            }
            .disabled(!isValid)
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

class DisplayLinkTarget {
    let callback: (CFTimeInterval) -> Void
    init(callback: @escaping (CFTimeInterval) -> Void) { self.callback = callback }
    @objc func step(link: CADisplayLink) { callback(link.timestamp) }
}

#Preview { ContentView() }
