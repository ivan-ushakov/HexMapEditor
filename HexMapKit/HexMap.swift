//
//  HexMap.swift
//  GlassKingdom
//
//  Created by  Ivan Ushakov on 17/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import Foundation
import SceneKit

typealias TFloat = CGFloat

struct HexMetrics {
    static let outerToInner = TFloat(0.866025404)
    static let innerToOuter = 1.0 / outerToInner
    
    static let outerRadius = TFloat(10.0)
    static let innerRadius = HexMetrics.outerRadius * HexMetrics.outerToInner
    
    static let solidFactor = TFloat(0.8)
    static let blendFactor = 1.0 - HexMetrics.solidFactor
    
    static let elevationStep = TFloat(3.0)
    
    static let terracesPerSlope = 2
    static let terraceSteps = HexMetrics.terracesPerSlope * 2 + 1
    
    static let horizontalTerraceStepSize = 1.0 / TFloat(terraceSteps)
    static let verticalTerraceStepSize = 1.0 / TFloat(terracesPerSlope + 1)
    
    static let chunkSizeX = 5
    static let chunkSizeZ = 5
    
    static let cellPerturbStrength = TFloat(0.5)
    static let elevationPerturbStrength = TFloat(1.5)
    
    static let streamBedElevationOffset = TFloat(-1.75)
    
    static let waterElevationOffset = TFloat(-0.5)
    
    static let waterFactor = TFloat(0.6)
    
    static let waterBlendFactor = TFloat(1.0 - HexMetrics.waterFactor)
    
    static let corners: Array<SCNVector3> = [SCNVector3(0, 0, HexMetrics.outerRadius),
                                             SCNVector3(HexMetrics.innerRadius, 0, 0.5 * HexMetrics.outerRadius),
                                             SCNVector3(HexMetrics.innerRadius, 0, -0.5 * HexMetrics.outerRadius),
                                             SCNVector3(0, 0, -HexMetrics.outerRadius),
                                             SCNVector3(-HexMetrics.innerRadius, 0, -0.5 * HexMetrics.outerRadius),
                                             SCNVector3(-HexMetrics.innerRadius, 0, 0.5 * HexMetrics.outerRadius),
                                             SCNVector3(0, 0, HexMetrics.outerRadius)]
    
    static func getFirstCorner(_ direction: HexDirection) -> SCNVector3 {
        return HexMetrics.corners[direction.rawValue]
    }
    
    static func getSecondCorner(_ direction: HexDirection) -> SCNVector3 {
        return HexMetrics.corners[direction.rawValue + 1]
    }
    
    static func getFirstSolidCorner(_ direction: HexDirection) -> SCNVector3 {
        return HexMetrics.corners[direction.rawValue] * HexMetrics.solidFactor
    }
    
    static func getSecondSolidCorner(_ direction: HexDirection) -> SCNVector3 {
        return HexMetrics.corners[direction.rawValue + 1] * HexMetrics.solidFactor
    }
    
    static func getSolidEdgeMiddle (_ direction: HexDirection ) -> SCNVector3 {
        let v = HexMetrics.corners[direction.rawValue] + HexMetrics.corners[direction.rawValue + 1]
        return v * (0.5 * HexMetrics.solidFactor)
    }
    
    static func getFirstWaterCorner(_ direction: HexDirection) -> SCNVector3 {
        return HexMetrics.corners[direction.rawValue] * HexMetrics.waterFactor
    }
    
    static func getSecondWaterCorner(_ direction: HexDirection) -> SCNVector3 {
        return HexMetrics.corners[direction.rawValue + 1] * HexMetrics.waterFactor
    }
    
    static func getBridge(_ direction: HexDirection) -> SCNVector3 {
        let v = HexMetrics.corners[direction.rawValue] + HexMetrics.corners[direction.rawValue + 1]
        return v * HexMetrics.blendFactor
    }
    
    static func getWaterBridge(_ direction: HexDirection) -> SCNVector3 {
        let v = HexMetrics.corners[direction.rawValue] + HexMetrics.corners[direction.rawValue + 1]
        return v * HexMetrics.waterBlendFactor
    }
    
    static func terraceLerp(a: SCNVector3, b: SCNVector3, step: Int) -> SCNVector3 {
        let h = TFloat(step) * HexMetrics.horizontalTerraceStepSize
        let x = a.x + (b.x - a.x) * h
        let z = a.z + (b.z - a.z) * h
        
        let v = TFloat((step + 1) / 2) * HexMetrics.verticalTerraceStepSize
        let y = a.y + (b.y - a.y) * v
        
        return SCNVector3(x: x, y: y, z: z)
    }
    
    static func terraceLerp(a: Color, b: Color, step: Int) -> Color {
        let h = Float(step) * Float(HexMetrics.horizontalTerraceStepSize)
        return ColorLerp(start: a, end: b, t: h)
    }
    
    static func getEdgeType(elevation1: Int, elevation2: Int) -> HexEdgeType {
        if elevation1 == elevation2 {
            return .Flat
        }
        
        let delta = elevation2 - elevation1
        if delta == 1 || delta == -1 {
            return .Slope
        }
        
        return .Cliff
    }
}

public struct HexCoordinates: Equatable {
    public var x: Int
    public var y: Int { return -x - z }
    public var z: Int
    
    public init(x: Int, z: Int) {
        self.x = x
        self.z = z
    }
}

extension HexCoordinates {
    static func createFromOffset(x: Int, z: Int) -> HexCoordinates {
        return HexCoordinates(x: x - z / 2, z: z)
    }
    
    static func createFromPosition(_ position: SCNVector3) -> HexCoordinates {
        var x = position.x / (HexMetrics.innerRadius * 2.0)
        var y = -x
        
        let offset = position.z / (HexMetrics.outerRadius * 3.0)
        x -= offset
        y -= offset
        
        var iX = Int(round(x))
        let iY = Int(round(y))
        var iZ = Int(round(-x - y))
        
        if iX + iY + iZ != 0 {
            let dX = abs(x - TFloat(iX))
            let dY = abs(y - TFloat(iY))
            let dZ = abs(-x - y - TFloat(iZ))
            
            if dX > dY && dX > dZ {
                iX = -iY - iZ
            } else if dZ > dY {
                iZ = -iX - iY
            }
        }
        
        return HexCoordinates(x: iX, z: iZ)
    }
}

class HexCell {
    var position: SCNVector3
    let coordinates: HexCoordinates
    
    var elevation = 0 {
        didSet {
            self.position.y = TFloat(self.elevation) * HexMetrics.elevationStep
            self.position.y += NoiseSource.shared.get(self.position).y * HexMetrics.elevationPerturbStrength
            
            if self.hasOutgoingRiver {
                if let neighbor = getNeighbor(self.outgoingRiver) {
                    if self.elevation < neighbor.elevation {
                        removeOutgoingRiver()
                    }
                }
            }
            
            if self.hasIncomingRiver {
                if let neighbor = getNeighbor(self.incomingRiver) {
                    if self.elevation > neighbor.elevation {
                        removeIncomingRiver()
                    }
                }
            }
        }
    }
    
    var terrainTypeIndex = 0
    
    var hasIncomingRiver: Bool
    var incomingRiver: HexDirection
    
    var hasOutgoingRiver: Bool
    var outgoingRiver: HexDirection
    
    var hasRiver: Bool {
        return self.hasIncomingRiver || self.hasOutgoingRiver
    }
    
    var hasRiverBeginOrEnd: Bool {
        return self.hasIncomingRiver != self.hasOutgoingRiver
    }
    
    var streamBedY: TFloat {
        return (TFloat(self.elevation) + HexMetrics.streamBedElevationOffset) * HexMetrics.elevationStep
    }
    
    var riverSurfaceY: TFloat {
        return (TFloat(self.elevation) + HexMetrics.waterElevationOffset) * HexMetrics.elevationStep
    }
    
    var waterSurfaceY: TFloat {
        return (TFloat(self.waterLevel) + HexMetrics.waterElevationOffset) * HexMetrics.elevationStep
    }
    
    var waterLevel = 0
    
    var isUnderwater: Bool {
        return self.waterLevel > self.elevation
    }
    
    private var neighbors = [HexCell?]()
    
    init(position: SCNVector3, coordinates: HexCoordinates) {
        self.position = position
        self.coordinates = coordinates
        
        self.hasIncomingRiver = false
        self.incomingRiver = .E
        
        self.hasOutgoingRiver = false
        self.outgoingRiver = .E
        
        for _ in 0..<6 {
            self.neighbors.append(nil)
        }
    }
    
    func getNeighbor(_ direction: HexDirection) -> HexCell? {
        return self.neighbors[direction.rawValue]
    }
    
    func setNeighbor(direction: HexDirection, cell: HexCell) {
        self.neighbors[direction.rawValue] = cell
        cell.neighbors[direction.opposite().rawValue] = self
    }
    
    func getEdgeType(_ direction: HexDirection) -> HexEdgeType {
        guard let neighbor = self.neighbors[direction.rawValue] else { fatalError() }
        return HexMetrics.getEdgeType(elevation1: self.elevation, elevation2: neighbor.elevation)
    }
    
    func getEdgeType(_ otherCell: HexCell ) -> HexEdgeType {
        return HexMetrics.getEdgeType(elevation1: self.elevation, elevation2: otherCell.elevation)
    }
    
    func hasRiverThroughEdge(_ direction: HexDirection) -> Bool {
        return self.hasIncomingRiver && self.incomingRiver == direction ||
            self.hasOutgoingRiver && self.outgoingRiver == direction
    }
    
    func removeOutgoingRiver() {
        if !self.hasOutgoingRiver {
            return
        }
        
        self.hasOutgoingRiver = false
        
        let neighbor = getNeighbor(self.outgoingRiver)
        neighbor?.hasIncomingRiver = false
    }
    
    func removeIncomingRiver() {
        if !self.hasIncomingRiver {
            return
        }
        
        self.hasIncomingRiver = false
        
        if let neighbor = getNeighbor(self.incomingRiver) {
            neighbor.hasOutgoingRiver = false
        }
    }
    
    func removeRiver() {
        removeOutgoingRiver()
        removeIncomingRiver()
    }
    
    func setOutgoingRiver(_ direction: HexDirection) {
        if self.hasOutgoingRiver && self.outgoingRiver == direction {
            return
        }
        
        guard let neighbor = getNeighbor(direction) else {
            return
        }
        
        if self.elevation < neighbor.elevation {
            return
        }
        
        removeOutgoingRiver()
        if self.hasIncomingRiver && self.incomingRiver == direction {
            removeIncomingRiver()
        }
        
        self.hasOutgoingRiver = true
        self.outgoingRiver = direction
        
        neighbor.removeIncomingRiver()
        neighbor.hasIncomingRiver = true
        neighbor.incomingRiver = direction.opposite()
    }
}

public enum HexDirection: Int, CaseIterable {
    case NE, E, SE, SW, W, NW
}

extension HexDirection {
    func opposite() -> HexDirection {
        let result: HexDirection?
        if self.rawValue < 3 {
            result = HexDirection(rawValue: self.rawValue + 3)
        } else {
            result = HexDirection(rawValue: self.rawValue - 3)
        }
        
        guard let p = result else { fatalError() }
        return p
    }
    
    func previous() -> HexDirection {
        let result: HexDirection?
        if self == HexDirection.NE {
            result = HexDirection.NW
        } else {
            result = HexDirection(rawValue: self.rawValue - 1)
        }
        
        guard let p = result else { fatalError() }
        return p
    }
    
    func next() -> HexDirection {
        let result: HexDirection?
        if self == HexDirection.NW {
            result = HexDirection.NE
        } else {
            result = HexDirection(rawValue: self.rawValue + 1)
        }
        
        guard let p = result else { fatalError() }
        return p
    }
    
    func previous2() -> HexDirection {
        let direction = self.rawValue - 2
        
        let result: HexDirection?
        if direction >= HexDirection.NE.rawValue {
            result = HexDirection(rawValue: direction)
        } else {
            result = HexDirection(rawValue: direction + 6)
        }
        
        guard let p = result else { fatalError() }
        return p
    }
    
    func next2() -> HexDirection {
        let direction = self.rawValue + 2
        
        let result: HexDirection?
        if direction <= HexDirection.NW.rawValue {
            result = HexDirection(rawValue: direction)
        } else {
            result = HexDirection(rawValue: direction - 6)
        }
        
        guard let p = result else { fatalError() }
        return p
    }
}

enum HexEdgeType {
    case Flat, Slope, Cliff
}

struct Color {
    static let color1 = Color(r: 1.0, g: 0.0, b: 0.0)
    static let color2 = Color(r: 0.0, g: 1.0, b: 0.0)
    static let color3 = Color(r: 0.0, g: 0.0, b: 1.0)
    
    var r: Float
    var g: Float
    var b: Float
}

func ColorLerp(start: Color, end: Color, t: Float) -> Color {
    return Color(r: start.r + (end.r - start.r) * t, g: start.g + (end.g - start.g) * t, b: start.b + (end.b - start.b) * t)
}

public class HexGrid {
    
    public let node = SCNNode()
    
    private let chunkCountX = 4
    private let chunkCountZ = 3
    
    private let cellCountX: Int
    private let cellCountZ: Int
    
    private var cells = [HexCell]()
    
    private var chunks = [HexGridChunk]()
    
    public init() {
        self.cellCountX = self.chunkCountX * HexMetrics.chunkSizeX
        self.cellCountZ = self.chunkCountZ * HexMetrics.chunkSizeZ

        self.node.name = "HexGrid"

        createChunks()
        createCells()
    }
    
    public func start() {
        self.chunks.forEach { $0.start() }
    }
    
    public func getCoordinates(_ position: SCNVector3) -> HexCoordinates {
        return HexCoordinates.createFromPosition(position)
    }
    
    public func setCellTerrainTypeIndex(coordinates: HexCoordinates, terrainTypeIndex: Int) {
        let cell = getCell(coordinates)
        cell.terrainTypeIndex = terrainTypeIndex
    }
    
    public func setCellElevation(coordinates: HexCoordinates, elevation: Int) {
        let cell = getCell(coordinates)
        cell.elevation = elevation
    }
    
    public func setCellWaterLevel(coordinates: HexCoordinates, waterLevel: Int) {
        let cell = getCell(coordinates)
        cell.waterLevel = waterLevel
    }
    
    public func removeRiver(_ coordinates: HexCoordinates) {
        let cell = getCell(coordinates)
        cell.removeRiver()
    }
    
    public func setOutgoindRiver(coordinates: HexCoordinates, direction: HexDirection) {
        let cell = getCell(coordinates)
        cell.setOutgoingRiver(direction)
    }
    
    public func findDirection(from: HexCoordinates, to: HexCoordinates) -> HexDirection? {
        let cell = getCell(from)
        
        for direction in HexDirection.allCases {
            if cell.getNeighbor(direction)?.coordinates == to {
                return direction
            }
        }
        
        return nil
    }
    
    private func createChunks() {
        for _ in 0..<self.chunkCountZ {
            for _ in 0..<self.chunkCountX {
                let chunk = HexGridChunk()
                self.chunks.append(chunk)

                self.node.addChildNode(chunk.node)
            }
        }
    }
    
    private func createCells() {
        var i = 0
        for z in 0..<self.cellCountZ {
            for x in 0..<self.cellCountX {
                createCell(x: x, z: z, i: i)
                i += 1
            }
        }
    }
    
    private func createCell(x: Int, z: Int, i: Int) {
        let px = 2 * HexMetrics.innerRadius * (TFloat(x) + 0.5 * TFloat(z) - TFloat(z / 2))
        let pz = 1.5 * HexMetrics.outerRadius * TFloat(z)
        
        let coordinates = HexCoordinates.createFromOffset(x: x, z: z)
        let cell = HexCell(position: SCNVector3(px, 0, pz), coordinates: coordinates)
        
        if x > 0 {
            cell.setNeighbor(direction: .W, cell: self.cells[i - 1])
        }
        
        if z > 0 {
            if z & 1 == 0 {
                cell.setNeighbor(direction: .SE, cell: self.cells[i - cellCountX])
                if x > 0 {
                    cell.setNeighbor(direction: .SW, cell: self.cells[i - cellCountX - 1])
                }
            } else {
                cell.setNeighbor(direction: .SW, cell: self.cells[i - cellCountX])
                if x < cellCountX - 1 {
                    cell.setNeighbor(direction: .SE, cell: self.cells[i - cellCountX + 1])
                }
            }
        }
        
        cell.elevation = 0
        
        self.cells.append(cell)
        
        addCellToChunk(x: x, z: z, cell: cell)
    }
    
    private func addCellToChunk(x: Int, z: Int, cell: HexCell) {
        let chunkX = x / HexMetrics.chunkSizeX
        let chunkZ = z / HexMetrics.chunkSizeZ
        let chunk = self.chunks[chunkX + chunkZ * self.chunkCountX]
        chunk.addCell(cell)
    }
    
    private func getCell(_ coordinates: HexCoordinates) -> HexCell {
        let index = coordinates.x + coordinates.z * cellCountX + coordinates.z / 2
        return self.cells[index]
    }
}

struct Edge {
    var v1: SCNVector3
    var v2: SCNVector3
    var v3: SCNVector3
    var v4: SCNVector3
    var v5: SCNVector3
}

extension Edge {
    init(corner1: SCNVector3, corner2: SCNVector3) {
        self.v1 = corner1
        self.v2 = SCNVector3Lerp(vectorStart: corner1, vectorEnd: corner2, t: 0.25)
        self.v3 = SCNVector3Lerp(vectorStart: corner1, vectorEnd: corner2, t: 0.5)
        self.v4 = SCNVector3Lerp(vectorStart: corner1, vectorEnd: corner2, t: 0.75)
        self.v5 = corner2
    }
    
    init(corner1: SCNVector3, corner2: SCNVector3, outerStep: TFloat) {
        self.v1 = corner1
        self.v2 = SCNVector3Lerp(vectorStart: corner1, vectorEnd: corner2, t: outerStep)
        self.v3 = SCNVector3Lerp(vectorStart: corner1, vectorEnd: corner2, t: 0.5)
        self.v4 = SCNVector3Lerp(vectorStart: corner1, vectorEnd: corner2, t: 1.0 - outerStep)
        self.v5 = corner2
    }
    
    static func terraceLerp(a: Edge, b: Edge, step: Int) -> Edge {
        let v1 = HexMetrics.terraceLerp(a: a.v1, b: b.v1, step: step)
        let v2 = HexMetrics.terraceLerp(a: a.v2, b: b.v2, step: step)
        let v3 = HexMetrics.terraceLerp(a: a.v3, b: b.v3, step: step)
        let v4 = HexMetrics.terraceLerp(a: a.v4, b: b.v4, step: step)
        let v5 = HexMetrics.terraceLerp(a: a.v5, b: b.v5, step: step)
        return Edge(v1: v1, v2: v2, v3: v3, v4: v4, v5: v5)
    }
}

func update(v: SCNVector3, y: TFloat) -> SCNVector3 {
    var t = v
    t.y = y
    return t
}
