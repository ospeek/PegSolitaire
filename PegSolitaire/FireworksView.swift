//
//  FireworksView.swift
//  PegSolitaire
//
//  Created by Onno Speekenbrink on 2025-08-11.
//

import SwiftUI

struct FireworksView: View {
    @State private var fireworks: [Firework] = []
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background fireworks
            ForEach(fireworks) { firework in
                FireworkParticle(firework: firework)
            }
        }
        .onAppear {
            startFireworks()
        }
        .onDisappear {
            stopFireworks()
        }
    }

    private func startFireworks() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            createNewFirework()
        }
    }

    private func stopFireworks() {
        timer?.invalidate()
        timer = nil
    }

    private func createNewFirework() {
        let newFirework = Firework()
        fireworks.append(newFirework)

        // Remove old fireworks after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            fireworks.removeAll { $0.id == newFirework.id }
        }
    }
}

struct Firework: Identifiable {
    let id = UUID()
    let startPosition: CGPoint
    let color: Color
    let particles: [FireworkParticleData]

    init() {
        let screenWidth = UIScreen.main.bounds.width
        startPosition = CGPoint(
            x: CGFloat.random(in: 10...(screenWidth - 20)),
            y: UIScreen.main.bounds.height + 5
        )

        color = [.yellow, .red, .blue, .green, .orange, .pink, .purple, .cyan, .mint].randomElement() ?? .yellow

        // Create more particles for each firework
        var particleData: [FireworkParticleData] = []
        for _ in 0..<25 {
            particleData.append(FireworkParticleData())
        }
        particles = particleData
    }
}

struct FireworkParticleData {
    let angle: Double
    let velocity: Double
    let delay: Double

    init() {
        angle = Double.random(in: 0...(2 * .pi))
        velocity = Double.random(in: 300...600)
        delay = Double.random(in: 0...0.3)
    }
}

struct FireworkParticle: View {
    let firework: Firework

    var body: some View {
        ZStack {
            ForEach(Array(firework.particles.enumerated()), id: \.offset) { index, particle in
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(firework.color)
                        .frame(width: 16, height: 16)
                        .shadow(color: firework.color, radius: 8, x: 0, y: 0)

                    // Inner bright core
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .white, radius: 4, x: 0, y: 0)
                }
                .offset(
                    x: firework.startPosition.x,
                    y: firework.startPosition.y
                )
                .modifier(FireworkAnimation(particle: particle))
            }
        }
    }
}

struct FireworkAnimation: ViewModifier {
    let particle: FireworkParticleData
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .offset(
                x: isAnimating ? cos(particle.angle) * particle.velocity : 0,
                y: isAnimating ? sin(particle.angle) * particle.velocity - 300 : 0
            )
            .opacity(isAnimating ? 0 : 1)
            .scaleEffect(isAnimating ? 0.3 : 1.0)
            .animation(
                .easeOut(duration: 3.0)
                .delay(particle.delay),
                value: isAnimating
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }
    }
}

struct WinView: View {
    var newGame: () -> Void
    var moveCount: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.black.opacity(0.95), Color.purple.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Fireworks overlay - ensure it covers the full screen
                FireworksView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()

                // Content
                VStack(spacing: 30) {
                    Spacer()

                    Text("🎉")
                        .font(.system(size: 80))
                        .shadow(radius: 15)

                    Text("Congratulations!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                        .multilineTextAlignment(.center)

                    Text("Moves: \(moveCount)")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 5)

                    Text("You solved the puzzle!")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 5)

                    Spacer()

                    Button("New Game", action: newGame)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .font(.title2)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 15)

                    Spacer()
                }
                .padding()
            }
        }
    }
}
