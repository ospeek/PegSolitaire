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
    @State private var multiMovePaths: [Position: [Move]] = [:]
    @State private var history: [Board] = []
    @State private var showGameOver = false
    @State private var showWin = false
    @State private var orientationAngle: Angle = .degrees(0)
    @State private var draggingFrom: Position? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false

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
                        updateMultiMovePaths()
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
        let gap: CGFloat = 4
        let step = cellSize + gap
        return ZStack {
            VStack(spacing: gap) {
                ForEach(0..<Board.size, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<Board.size, id: \.self) { c in
                            cellView(row: r, col: c, cellSize: cellSize)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }

            // Dragging overlay: a peg that follows the finger
            if let start = draggingFrom, isDragging {
                PegView(isSelected: true)
                    .frame(width: cellSize, height: cellSize)
                    .position(
                        x: step * CGFloat(start.col) + cellSize / 2 + dragTranslation.width,
                        y: step * CGFloat(start.row) + cellSize / 2 + dragTranslation.height
                    )
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
                    .opacity(draggingFrom == pos && isDragging ? 0 : 1)
                    .onTapGesture {
                        handleTap(on: pos)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if selected != pos {
                                    handleTap(on: pos)
                                }
                                if draggingFrom == nil {
                                    draggingFrom = pos
                                    isDragging = true
                                }
                                dragTranslation = value.translation
                            }
                            .onEnded { value in
                                defer {
                                    isDragging = false
                                    dragTranslation = .zero
                                    draggingFrom = nil
                                }
                                guard let start = draggingFrom else { return }
                                let gap: CGFloat = 4
                                let step = cellSize + gap
                                let startCenterX = step * CGFloat(start.col) + cellSize / 2
                                let startCenterY = step * CGFloat(start.row) + cellSize / 2
                                let finalX = startCenterX + value.translation.width
                                let finalY = startCenterY + value.translation.height
                                let dropCol = Int(round((finalX - cellSize / 2) / step))
                                let dropRow = Int(round((finalY - cellSize / 2) / step))
                                let drop = Position(row: dropRow, col: dropCol)
                                if let path = multiMovePaths[drop] {
                                    attemptMultiMove(path)
                                } else if let sel = selected, let single = board.moves(from: sel).first(where: { $0.to == drop }) {
                                    attemptMove(single)
                                } else {
                                    selected = nil
                                    updateMultiMovePaths()
                                }
                            }
                    )
            }
        }
    }

    func destinationHighlight(_ pos: Position) -> some View {
        let dests = Set(multiMovePaths.keys)
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
            if multiMovePaths.count == 1, let path = multiMovePaths.values.first {
                attemptMultiMove(path)
            } else {
                selected = nil
                updateMultiMovePaths()
            }
            return
        }

        if board.moves(from: pos).isEmpty {
            selected = nil
        } else {
            selected = pos
        }
        updateMultiMovePaths()
    }

    func attemptMove(_ move: Move) {
        history.append(board)
        withAnimation(.easeInOut(duration: 0.6)) {
            board.movePeg(from: move.from, to: move.to)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.6)) {
                board.removePeg(at: move.over)
            }
            evaluateGameState()
        }
        selected = nil
        updateMultiMovePaths()
        evaluateGameState()
    }

    func attemptMove(from: Position, to: Position) {
        if let path = multiMovePaths[to] {
            attemptMultiMove(path)
        } else if let move = board.moves(from: from).first(where: { $0.to == to }) {
            attemptMove(move)
        } else {
            selected = nil
            updateMultiMovePaths()
        }
    }

    func attemptMultiMove(_ moves: [Move]) {
        history.append(board)
        withAnimation(.easeInOut(duration: 0.6)) {
            for m in moves {
                board.apply(m)
            }
        }
        selected = nil
        updateMultiMovePaths()
        evaluateGameState()
    }

    func undo() {
        if let last = history.popLast() {
            board = last
            selected = nil
            updateMultiMovePaths()
        }
    }

    func newGame() {
        board = Board.standard()
        history = []
        selected = nil
        updateMultiMovePaths()
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

    func updateMultiMovePaths() {
        if let sel = selected {
            multiMovePaths = board.multiMoveDestinations(from: sel)
        } else {
            multiMovePaths = [:]
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
