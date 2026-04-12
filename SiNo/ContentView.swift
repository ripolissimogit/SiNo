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
    var isCards: Bool = false
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
    Preset(id: "gostop", positive: "GO", negative: "STOP",
           positiveColor: Color(red: 0.0, green: 0.9, blue: 0.6),
           negativeColor: Color(red: 0.9, green: 0.2, blue: 0.1),
           fontSize: 130),
    Preset(id: "doit", positive: "DO IT", negative: "SKIP",
           positiveColor: Color(red: 1.0, green: 0.8, blue: 0.0),
           negativeColor: Color(red: 0.5, green: 0.5, blue: 0.55),
           fontSize: 100),
    Preset(id: "yolo", positive: "YOLO", negative: "NOPE",
           positiveColor: Color(red: 1.0, green: 0.3, blue: 0.6),
           negativeColor: Color(red: 0.4, green: 0.4, blue: 0.9),
           fontSize: 110),
    Preset(id: "bet", positive: "BET", negative: "PASS",
           positiveColor: Color(red: 1.0, green: 0.6, blue: 0.0),
           negativeColor: Color(red: 0.6, green: 0.3, blue: 0.9),
           fontSize: 120),
    Preset(id: "wl", positive: "W", negative: "L",
           positiveColor: Color(red: 0.0, green: 1.0, blue: 0.5),
           negativeColor: Color(red: 1.0, green: 0.2, blue: 0.2),
           fontSize: 160),
    Preset(id: "sendit", positive: "SEND IT", negative: "BAIL",
           positiveColor: Color(red: 1.0, green: 0.5, blue: 0.0),
           negativeColor: Color(red: 0.4, green: 0.4, blue: 0.5),
           fontSize: 90),
    Preset(id: "sayless", positive: "SAY LESS", negative: "I'M OUT",
           positiveColor: Color(red: 0.3, green: 0.9, blue: 0.7),
           negativeColor: Color(red: 0.8, green: 0.2, blue: 0.4),
           fontSize: 75),
    Preset(id: "lesgo", positive: "LESGO", negative: "BRUH",
           positiveColor: Color(red: 0.9, green: 0.9, blue: 0.0),
           negativeColor: Color(red: 0.5, green: 0.3, blue: 0.7),
           fontSize: 100),
    Preset(id: "daimai", positive: "DAI", negative: "MAI",
           positiveColor: Color(red: 1.0, green: 0.8, blue: 0.0),
           negativeColor: Color(red: 0.5, green: 0.5, blue: 0.55),
           fontSize: 130),
    Preset(id: "fallo", positive: "FALLO", negative: "FUGGI",
           positiveColor: Color(red: 0.2, green: 0.8, blue: 0.4),
           negativeColor: Color(red: 0.9, green: 0.1, blue: 0.1),
           fontSize: 100),
    Preset(id: "cards", positive: "SÌ", negative: "NO",
           positiveColor: Color(red: 0.2, green: 0.8, blue: 0.4),
           negativeColor: Color(red: 0.9, green: 0.25, blue: 0.3),
           fontSize: 140, isCards: true),
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
    @State private var textScale: CGFloat = 1.0
    @State private var glowRadius: CGFloat = 0
    @State private var bgFlash: Double = 0

    @State private var showCoachMark = false
    @State private var handOffset: CGFloat = -60
    @State private var handOpacity: Double = 0
    @State private var showTagline = true
    @State private var taglineOpacity: Double = 0

    @State private var showSettings = false
    @State private var showCustomSheet = false
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
                if preset.isCards {
                    if showingPositive {
                        Image("card_positive")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image("card_negative")
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(x: currentAxis == .horizontal ? -1 : 1,
                                         y: currentAxis == .vertical ? -1 : 1)
                    }
                } else {
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
            }
            .rotation3DEffect(.degrees(angle), axis: rotationAxis, perspective: 0.3)
            .scaleEffect(textScale)


            // Settings button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showSettings.toggle()
                        }
                    } label: {
                        Image(systemName: showSettings ? "xmark.circle.fill" : "ellipsis.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(showSettings ? 0.6 : 0.3))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 8)
                Spacer()
            }
            .zIndex(2)

            // Settings panel
            if showSettings {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showSettings = false
                        }
                    }
                    .zIndex(3)

                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    VStack(spacing: 16) {
                        // Preset grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            ForEach(builtInPresets) { p in
                                let isSelected = p.id == selectedPresetId
                                Button {
                                    selectedPresetId = p.id
                                    resetState()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        showSettings = false
                                    }
                                } label: {
                                    if p.isCards {
                                        HStack(spacing: 6) {
                                            Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.7))
                                            Text("Carte")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(isSelected
                                                      ? .white.opacity(0.2)
                                                      : .white.opacity(0.07))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? .white.opacity(0.3) : .clear, lineWidth: 1)
                                        )
                                    } else {
                                        HStack(spacing: 4) {
                                            Text(p.positive)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(p.positiveColor)
                                            Text("/")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.3))
                                            Text(p.negative)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(p.negativeColor)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(isSelected
                                                      ? .white.opacity(0.2)
                                                      : .white.opacity(0.07))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? .white.opacity(0.3) : .clear, lineWidth: 1)
                                        )
                                    }
                                }
                            }

                            // Custom button
                            Button {
                                editPositive = customPositive
                                editNegative = customNegative
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showSettings = false
                                }
                                showCustomSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Tuo")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedPresetId == "custom"
                                              ? .white.opacity(0.2)
                                              : .white.opacity(0.07))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedPresetId == "custom" ? .white.opacity(0.3) : .clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                .zIndex(4)
            }


            // Tagline
            if showTagline {
                VStack {
                    Spacer()
                    Text("I'll decide for you.\nJust swipe.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(taglineOpacity)
                        .padding(.bottom, 80)
                }
                .allowsHitTesting(false)
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
            withAnimation(.easeIn(duration: 1.0).delay(0.3)) { taglineOpacity = 1 }
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
                        dismissTagline()

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
                    } else {
                        velocity = gestureVelocity
                        haptic.prepare()
                        heavyHaptic.prepare()
                        lastFace = showingPositive
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
    }

    func resetState() {
        angle = 0
        showResult = false
        bgFlash = 0
        glowRadius = 0
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

    func dismissTagline() {
        guard showTagline else { return }
        withAnimation(.easeOut(duration: 0.3)) { taglineOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showTagline = false }
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
