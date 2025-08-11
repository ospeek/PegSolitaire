//
//  GameBoard.swift
//  PegSolitaire
//
//  Created by Onno Speekenbrink on 2025-08-11.
//

import Foundation

struct Position: Hashable {
    var row: Int
    var col: Int
}

enum Cell {
    case invalid
    case empty
    case peg
}

struct Move: Hashable {
    let from: Position
    let over: Position
    let to: Position
}

struct Board {
    private(set) var cells: [[Cell]]
    static let size = 7

    static func standard() -> Board {
        var cells = Array(repeating: Array(repeating: Cell.invalid, count: size), count: size)
        let valid = [
            [false,false,true,true,true,false,false],
            [false,false,true,true,true,false,false],
            [true,true,true,true,true,true,true],
            [true,true,true,false,true,true,true],
            [true,true,true,true,true,true,true],
            [false,false,true,true,true,false,false],
            [false,false,true,true,true,false,false]
        ]
        for r in 0..<size {
            for c in 0..<size {
                if valid[r][c] {
                    cells[r][c] = .peg
                }
            }
        }
        cells[3][3] = .empty
        return Board(cells: cells)
    }

    func cell(at p: Position) -> Cell {
        guard p.row >= 0 && p.row < Self.size && p.col >= 0 && p.col < Self.size else { return .invalid }
        return cells[p.row][p.col]
    }

    func moves(from p: Position) -> [Move] {
        guard cell(at: p) == .peg else { return [] }
        var result: [Move] = []
        let dirs = [(-1,0),(1,0),(0,-1),(0,1)]
        for d in dirs {
            let over = Position(row: p.row + d.0, col: p.col + d.1)
            let dest = Position(row: p.row + 2*d.0, col: p.col + 2*d.1)
            if cell(at: over) == .peg && cell(at: dest) == .empty {
                result.append(Move(from: p, over: over, to: dest))
            }
        }
        return result
    }

    func allMoves() -> [Move] {
        var result: [Move] = []
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                result.append(contentsOf: moves(from: Position(row: r, col: c)))
            }
        }
        return result
    }

    mutating func apply(_ move: Move) {
        cells[move.from.row][move.from.col] = .empty
        cells[move.over.row][move.over.col] = .empty
        cells[move.to.row][move.to.col] = .peg
    }

    mutating func movePeg(from: Position, to: Position) {
        cells[from.row][from.col] = .empty
        cells[to.row][to.col] = .peg
    }

    mutating func removePeg(at pos: Position) {
        cells[pos.row][pos.col] = .empty
    }

    func pegCount() -> Int {
        cells.flatMap { $0 }.filter { if case .peg = $0 { return true } else { return false } }.count
    }
}
