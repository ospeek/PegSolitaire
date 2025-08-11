//
//  ContentView.swift
//  PegSolitaire
//
//  Created by Onno Speekenbrink on 2025-08-11.
//

import SwiftUI

struct ContentView: View {
    @State private var board = Board.standard()
    @State private var selected: Position? = nil
    @State private var history: [Board] = []
    @State private var showGameOver = false
    @State private var showWin = false
    @State private var orientationAngle: Angle = .degrees(0)

    var body: some View {
        GeometryReader { geo in
            let padding: CGFloat = 20
            let boardSize = min(geo.size.width, geo.size.height) - padding * 2
            VStack {
                Spacer()
                boardView(size: boardSize)
                    .rotationEffect(orientationAngle)
                    .padding(padding)
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture {
                        selected = nil
                    }
                Spacer()
                HStack {
                    Button(action: newGame) {
                        Image(systemName: "arrow.clockwise")
                            .font(.largeTitle)
                    }
                    Spacer()
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.largeTitle)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            orientationAngle = angle(for: UIDevice.current.orientation)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientationAngle = angle(for: UIDevice.current.orientation)
        }
        .alert("Game Over", isPresented: $showGameOver) {
            Button("New Game", action: newGame)
            Button("Undo", action: undo)
        } message: {
            Text("\(board.pegCount()) pegs left")
        }
        .fullScreenCover(isPresented: $showWin) {
            WinView {
                newGame()
            }
        }
    }

    func angle(for orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft: return .degrees(90)
        case .landscapeRight: return .degrees(-90)
        case .portraitUpsideDown: return .degrees(180)
        default: return .degrees(0)
        }
    }

    func boardView(size: CGFloat) -> some View {
        let cellSize = size / CGFloat(Board.size)
        return VStack(spacing: 4) {
            ForEach(0..<Board.size, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<Board.size, id: \.self) { c in
                        cellView(row: r, col: c, cellSize: cellSize)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }

    func cellView(row: Int, col: Int, cellSize: CGFloat) -> some View {
        let pos = Position(row: row, col: col)
        return Group {
            switch board.cell(at: pos) {
            case .invalid:
                Color.clear
            case .empty:
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .background(destinationHighlight(pos))
                    .onTapGesture {
                        if let sel = selected {
                            attemptMove(from: sel, to: pos)
                        }
                    }
            case .peg:
                PegView(isSelected: selected == pos)
                    .onTapGesture {
                        handleTap(on: pos)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                handleTap(on: pos)
                            }
                            .onEnded { value in
                                let threshold = cellSize / 2
                                let dx = value.translation.width
                                let dy = value.translation.height
                                var dest: Position?
                                if abs(dx) > abs(dy) {
                                    if dx > threshold { dest = Position(row: row, col: col+2) }
                                    else if dx < -threshold { dest = Position(row: row, col: col-2) }
                                } else {
                                    if dy > threshold { dest = Position(row: row+2, col: col) }
                                    else if dy < -threshold { dest = Position(row: row-2, col: col) }
                                }
                                if let d = dest {
                                    attemptMove(from: pos, to: d)
                                }
                            }
                    )
            }
        }
    }

    func destinationHighlight(_ pos: Position) -> some View {
        let dests = selected.map { Set(board.moves(from: $0).map { $0.to }) } ?? []
        return Group {
            if dests.contains(pos) {
                Circle()
                    .fill(Color.primary.opacity(0.2))
            } else {
                Color.clear
            }
        }
    }

    func handleTap(on pos: Position) {
        if selected == pos {
            let moves = board.moves(from: pos)
            if moves.count == 1 {
                attemptMove(moves[0])
            } else {
                selected = nil
            }
            return
        }

        if board.moves(from: pos).isEmpty {
            selected = nil
        } else {
            selected = pos
        }
    }

    func attemptMove(_ move: Move) {
        history.append(board)
        withAnimation(.easeInOut(duration: 0.6)) {
            board.apply(move)
        }
        selected = nil
        evaluateGameState()
    }

    func attemptMove(from: Position, to: Position) {
        let moves = board.moves(from: from)
        if let move = moves.first(where: { $0.to == to }) {
            attemptMove(move)
        } else if board.moves(from: to).count > 0 {
            selected = to
        } else {
            selected = nil
        }
    }

    func undo() {
        if let last = history.popLast() {
            board = last
            selected = nil
        }
    }

    func newGame() {
        board = Board.standard()
        history = []
        selected = nil
        showWin = false
        showGameOver = false
    }

    func evaluateGameState() {
        if board.pegCount() == 1 {
            showWin = true
        } else if board.allMoves().isEmpty {
            showGameOver = true
        }
    }
}

struct PegView: View {
    var isSelected: Bool
    var body: some View {
        Circle()
            .fill(Color.primary)
            .overlay(
                Circle().stroke(Color.primary, lineWidth: isSelected ? 4 : 0)
            )
            .transition(.opacity)
    }
}
