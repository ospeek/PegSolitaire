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
    @State private var multiMovePaths: [Position: [[Move]]] = [:]
    @State private var history: [Board] = []
    @State private var showGameOver = false
    @State private var showWin = false
    @State private var orientationAngle: Angle = .degrees(0)
    @State private var draggingFrom: Position? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var moveCount: Int = 0
    @State private var currentDragPath: [Move]? = nil
    @State private var dragTarget: Position? = nil

    private let moveAnimationDuration: Double = 0.22
    private var moveAnimation: Animation { .easeInOut(duration: moveAnimationDuration) }

    var body: some View {
        GeometryReader { geo in
            let padding: CGFloat = 20
            let boardSize = min(geo.size.width, geo.size.height) - padding * 2
            VStack {
                HStack {
                    Spacer()
                    Text("Moves: \(moveCount)")
                        .font(.headline)
                }
                .padding(.top, 10)
                .padding(.trailing, 20)
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
            WinView(newGame: newGame, moveCount: moveCount)
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

                // Show the current drag path
                if let path = currentDragPath, !path.isEmpty {
                    ForEach(Array(path.enumerated()), id: \.offset) { index, move in
                        Circle()
                            .fill(Color.blue.opacity(0.5))
                            .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                            .position(
                                x: step * CGFloat(move.over.col) + cellSize / 2,
                                y: step * CGFloat(move.over.row) + cellSize / 2
                            )
                    }

                    // Show the path number and target
                    if let target = dragTarget {
                        Text("\(path.count)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white.opacity(0.8)))
                            .position(
                                x: step * CGFloat(target.col) + cellSize / 2,
                                y: step * CGFloat(target.row) + cellSize / 2
                            )
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
                            // Allow clicking if there's at least one path to this target
                            if let paths = multiMovePaths[pos], !paths.isEmpty {
                                // Use the first available path
                                attemptMultiMove(paths[0])
                            }
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
                                    currentDragPath = nil
                                    dragTarget = nil
                                }

                                // Track the drag path in real-time
                                let gap: CGFloat = 4
                                let step = cellSize + gap
                                let startCenterX = step * CGFloat(pos.col) + cellSize / 2
                                let startCenterY = step * CGFloat(pos.row) + cellSize / 2
                                let currentX = startCenterX + value.translation.width
                                let currentY = startCenterY + value.translation.height
                                let currentCol = Int(round((currentX - cellSize / 2) / step))
                                let currentRow = Int(round((currentY - cellSize / 2) / step))
                                let currentPos = Position(row: currentRow, col: currentCol)

                                // Build the drag path step by step as user drags
                                if board.isValidPosition(currentPos) {
                                    print("Current pos: \(currentPos), Starting pos: \(pos)")

                                    if currentDragPath == nil {
                                        // First move: from starting position to current position
                                        if let newMove = board.moves(from: pos).first(where: { $0.to == currentPos }) {
                                            currentDragPath = [newMove]
                                            dragTarget = currentPos
                                            print("Started path: \(newMove.from) -> \(newMove.over) -> \(newMove.to)")
                                        } else {
                                            print("No valid first move from \(pos) to \(currentPos)")
                                        }
                                    } else {
                                        // Subsequent moves: extend the path from the last position
                                        if let lastMove = currentDragPath?.last {
                                            print("Looking for move from \(lastMove.to) to \(currentPos)")
                                            // Check if this move would be valid by simulating the board state
                                            if let newMove = board.findMoveInPath(from: lastMove.to, to: currentPos, path: currentDragPath ?? []) {
                                                currentDragPath?.append(newMove)
                                                dragTarget = currentPos
                                                print("Extended path: \(newMove.from) -> \(newMove.over) -> \(newMove.to)")
                                            } else {
                                                print("No valid move from \(lastMove.to) to \(currentPos)")
                                                // Check what moves are available from lastMove.to
                                                let availableMoves = board.moves(from: lastMove.to)
                                                print("Available moves from \(lastMove.to): \(availableMoves)")
                                            }
                                        }
                                    }
                                }

                                dragTranslation = value.translation
                            }
                            .onEnded { value in
                                defer {
                                    isDragging = false
                                    dragTranslation = .zero
                                    draggingFrom = nil
                                    currentDragPath = nil
                                    dragTarget = nil
                                }

                                // Use the tracked path if available
                                if let path = currentDragPath, !path.isEmpty {
                                    print("Executing tracked path with \(path.count) moves:")
                                    for (i, move) in path.enumerated() {
                                        print("  Move \(i): \(move.from) -> \(move.over) -> \(move.to)")
                                    }
                                    attemptMultiMove(path)
                                    return
                                }

                                // If no path was tracked, try to find a single move to the final position
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

                                if let sel = selected, let single = board.moves(from: sel).first(where: { $0.to == drop }) {
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
        Group {
            if let paths = multiMovePaths[pos], !paths.isEmpty {
                let firstPath = paths[0]
                let isMultiMove = firstPath.count > 1
                ZStack {
                    Circle()
                        .fill(isMultiMove ? Color.orange.opacity(0.3) : Color.green.opacity(0.3))
                    if isMultiMove {
                        Text("\(firstPath.count)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.primary)
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    func handleTap(on pos: Position) {
        if selected == pos {
            // Auto-execute if there's exactly one destination available
            if multiMovePaths.count == 1, let paths = multiMovePaths.values.first, !paths.isEmpty {
                attemptMultiMove(paths[0])
            } else {
                selected = nil
            }
            updateMultiMovePaths()
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
        withAnimation(moveAnimation) {
            board.movePeg(from: move.from, to: move.to)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + moveAnimationDuration) {
            withAnimation(moveAnimation) {
                board.removePeg(at: move.over)
            }
            evaluateGameState()
        }
        selected = nil
        updateMultiMovePaths()
        evaluateGameState()
        moveCount += 1
    }

    func attemptMove(from: Position, to: Position) {
        if let paths = multiMovePaths[to], !paths.isEmpty {
            attemptMultiMove(paths[0])
        } else if let move = board.moves(from: from).first(where: { $0.to == to }) {
            attemptMove(move)
        } else {
            selected = nil
            updateMultiMovePaths()
        }
    }

    func attemptMultiMove(_ moves: [Move]) {
        print("attemptMultiMove called with \(moves.count) moves")
        history.append(board)

        // Execute each move in sequence
        for (index, move) in moves.enumerated() {
            let delay = moveAnimationDuration * Double(index)
            print("Scheduling move \(index): \(move.from) -> \(move.over) -> \(move.to) with delay \(delay)")

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                print("Executing move \(index): \(move.from) -> \(move.over) -> \(move.to)")
                withAnimation(moveAnimation) {
                    // Move the peg to the next position
                    if index == 0 {
                        // First move: from start position to first intermediate position
                        print("Moving peg from \(move.from) to \(move.to)")
                        board.movePeg(from: move.from, to: move.to)
                    } else {
                        // Subsequent moves: from previous position to next position
                        let previousMove = moves[index - 1]
                        print("Moving peg from \(previousMove.to) to \(move.to)")
                        board.movePeg(from: previousMove.to, to: move.to)
                    }

                    // Remove the peg that was jumped over
                    print("Removing peg at \(move.over)")
                    board.removePeg(at: move.over)
                }

                // Evaluate game state after the last move completes
                if index == moves.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + moveAnimationDuration) {
                        print("All moves completed, evaluating game state. Peg count: \(board.pegCount())")
                        evaluateGameState()
                    }
                }
            }
        }

        selected = nil
        updateMultiMovePaths()
        moveCount += 1
    }

    func undo() {
        if let last = history.popLast() {
            board = last
            selected = nil
            updateMultiMovePaths()
            if moveCount > 0 { moveCount -= 1 }
        }
    }

    func newGame() {
        board = Board.standard()
        history = []
        selected = nil
        updateMultiMovePaths()
        showWin = false
        showGameOver = false
        moveCount = 0
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
            multiMovePaths = board.allMultiMoveDestinations(from: sel)
        } else {
            multiMovePaths = [:]
        }
        // Clear drag state when paths change
        currentDragPath = nil
        dragTarget = nil
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
