//
//  FireworksView.swift
//  PegSolitaire
//
//  Created by Onno Speekenbrink on 2025-08-11.
//

import SwiftUI
import UIKit

struct FireworksView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        FireworksUIView()
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class FireworksUIView: UIView {
    override class var layerClass: AnyClass { CAEmitterLayer.self }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let emitter = self.layer as? CAEmitterLayer else { return }
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY)
        emitter.emitterSize = CGSize(width: bounds.size.width, height: 2)
        emitter.emitterShape = .line
        emitter.renderMode = .additive

        let cell = CAEmitterCell()
        cell.birthRate = 3
        cell.lifetime = 3.0
        cell.velocity = 250
        cell.velocityRange = 100
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 4
        cell.scale = 0.02
        cell.scaleRange = 0.02
        cell.contents = UIImage(systemName: "star.fill")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal).cgImage
        cell.alphaSpeed = -0.4

        emitter.emitterCells = [cell]
    }
}

struct WinView: View {
    var newGame: () -> Void
    var body: some View {
        ZStack {
            FireworksView()
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Congratulations!")
                    .font(.largeTitle)
                    .bold()
                Button("New Game", action: newGame)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
