//
//  HexGridChunk.swift
//  HexMapKit
//
//  Created by  Ivan Ushakov on 12/12/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import SceneKit

class HexGridChunk {

    let node = SCNNode()

    private var cells = [HexCell]()

    private let terrain = HexMesh(.terrain)
    private let rivers = HexMesh(.rivers)
    private let water = HexMesh(.water)
    private let waterShore = HexMesh(.waterShore)

    init() {
        self.node.name = "HexGridChunk"

        self.terrain.useColors = true
        self.terrain.useTerrainTypes = true
        self.node.addChildNode(self.terrain.node)

        self.rivers.useTextureCoordinates = true
        self.node.addChildNode(self.rivers.node)

        self.water.useTextureCoordinates = true
        self.node.addChildNode(self.water.node)

        self.waterShore.useTextureCoordinates = true
        self.node.addChildNode(self.waterShore.node)
    }

    func start() {
        triangulate(self.cells)
    }

    func addCell(_ cell: HexCell) {
        self.cells.append(cell)
    }

    func triangulate(_ cells: [HexCell]) {
        self.terrain.clear()
        self.rivers.clear()
        self.water.clear()
        self.waterShore.clear()

        cells.forEach { triangulate($0) }

        self.terrain.apply()
        self.rivers.apply()
        self.water.apply()
        self.waterShore.apply()
    }

    private func triangulate(_ cell: HexCell) {
        HexDirection.allCases.forEach { direction in
            triangulate(direction: direction, cell: cell)
        }
    }

    private func triangulate(direction: HexDirection, cell: HexCell) {
        var center = cell.position
        let v1 = center + HexMetrics.getFirstSolidCorner(direction)
        let v2 = center + HexMetrics.getSecondSolidCorner(direction)

        var edge = Edge(corner1: v1, corner2: v2)

        if cell.hasRiver {
            if cell.hasRiverThroughEdge(direction) {
                edge.v3.y = cell.streamBedY
                if cell.hasRiverBeginOrEnd {
                    triangulateWithRiverBeginOrEnd(direction: direction, cell: cell, center: center, e: edge)
                } else {
                    triangulateWithRiver(direction: direction, cell: cell, center: center, e: edge)
                }
                center.y = cell.streamBedY
            } else {
                triangulateAdjacentToRiver(direction: direction, cell: cell, center: center, e: edge)
            }
        } else {
            triangulateWithoutRiver(direction: direction, cell: cell, center: center, e: edge)
        }

        if direction.rawValue <= HexDirection.SE.rawValue {
            triangulateConnection(direction: direction, cell: cell, e1: edge)
        }

        if cell.isUnderwater {
            triangulateWater(direction: direction, cell: cell, center: center)
        }
    }

    // MARK: River

    private func triangulateWithRiverBeginOrEnd(direction: HexDirection, cell: HexCell, center: SCNVector3, e: Edge) {
        var m = Edge(corner1: SCNVector3Lerp(vectorStart: center, vectorEnd: e.v1, t: 0.5),
                     corner2: SCNVector3Lerp(vectorStart: center, vectorEnd: e.v5, t: 0.5))

        m.v3.y = e.v3.y

        triangulateEdgeStrip(e1: m, c1: Color.color1, type1: Float(cell.terrainTypeIndex),
                             e2: e, c2: Color.color1, type2: Float(cell.terrainTypeIndex))

        triangulateEdgeFan(center: center, edge: m, type: Float(cell.terrainTypeIndex))

        let reversed = cell.hasIncomingRiver
        triangulateRiverQuad(v1: m.v2, v2: m.v4, v3: e.v2, v4: e.v4, y: cell.riverSurfaceY, v: 0.6, reversed: reversed)

        self.rivers.addTriangle(v1: update(v: center, y: cell.riverSurfaceY),
                                v2: update(v: m.v2, y: cell.riverSurfaceY),
                                v3: update(v: m.v4, y: cell.riverSurfaceY))
        if reversed {
            self.rivers.addTriangleUV(uv1: CGPoint(x: 0.5, y: 0.4), uv2: CGPoint(x: 1, y: 0.2), uv3: CGPoint(x: 0, y: 0.2))
        } else {
            self.rivers.addTriangleUV(uv1: CGPoint(x: 0.5, y: 0.4), uv2: CGPoint(x: 0, y: 0.6), uv3: CGPoint(x: 1, y: 0.6))
        }
    }

    private func triangulateWithRiver(direction: HexDirection, cell: HexCell, center: SCNVector3, e: Edge) {
        var centerL: SCNVector3
        var centerR: SCNVector3

        if cell.hasRiverThroughEdge(direction.opposite()) {
            centerL = center + HexMetrics.getFirstSolidCorner(direction.previous()) * 0.25
            centerR = center + HexMetrics.getSecondSolidCorner(direction.next()) * 0.25
        } else if cell.hasRiverThroughEdge(direction.next()) {
            centerL = center
            centerR = SCNVector3Lerp(vectorStart: center, vectorEnd: e.v5, t: 2.0 / 3.0)
        } else if cell.hasRiverThroughEdge(direction.previous()) {
            centerL = SCNVector3Lerp(vectorStart: center, vectorEnd: e.v1, t: 2.0 / 3.0)
            centerR = center
        } else if cell.hasRiverThroughEdge(direction.next2()) {
            centerL = center
            centerR = center + HexMetrics.getSolidEdgeMiddle(direction.next()) * (0.5 * HexMetrics.innerToOuter)
        } else {
            centerL = center + HexMetrics.getSolidEdgeMiddle(direction.previous()) * (0.5 * HexMetrics.innerToOuter)
            centerR = center
        }

        var m = Edge(corner1: SCNVector3Lerp(vectorStart: centerL, vectorEnd: e.v1, t: 0.5),
                     corner2: SCNVector3Lerp(vectorStart: centerR, vectorEnd: e.v5, t: 0.5),
                     outerStep: 1.0 / 6.0)

        m.v3.y = e.v3.y

        triangulateEdgeStrip(e1: m, c1: Color.color1, type1: Float(cell.terrainTypeIndex),
                             e2: e, c2: Color.color1, type2: Float(cell.terrainTypeIndex))

        self.terrain.addTriangle(v1: centerL, v2: m.v1, v3: m.v2)
        self.terrain.addQuad(v1: centerL, v2: center, v3: m.v2, v4: m.v3)
        self.terrain.addQuad(v1: center, v2: centerR, v3: m.v3, v4: m.v4)
        self.terrain.addTriangle(v1: centerR, v2: m.v4, v3: m.v5)

        self.terrain.addTriangleColor(Color.color1)
        self.terrain.addQuadColor(Color.color1)
        self.terrain.addQuadColor(Color.color1)
        self.terrain.addTriangleColor(Color.color1)

        let types = SCNVector3(Float(cell.terrainTypeIndex),
                               Float(cell.terrainTypeIndex),
                               Float(cell.terrainTypeIndex))
        self.terrain.addTriangleTerrainTypes(types)
        self.terrain.addQuadTerrainTypes(types)
        self.terrain.addQuadTerrainTypes(types)
        self.terrain.addTriangleTerrainTypes(types)

        let reversed = cell.incomingRiver == direction
        triangulateRiverQuad(v1: centerL, v2: centerR, v3: m.v2, v4: m.v4, y: cell.riverSurfaceY, v: 0.4, reversed: reversed)
        triangulateRiverQuad(v1: m.v2, v2: m.v4, v3: e.v2, v4: e.v4, y: cell.riverSurfaceY, v: 0.6, reversed: reversed)
    }

    private func triangulateAdjacentToRiver(direction: HexDirection, cell: HexCell, center: SCNVector3, e: Edge) {
        var c = center

        if cell.hasRiverThroughEdge(direction.next()) {
            if cell.hasRiverThroughEdge(direction.previous()) {
                c += HexMetrics.getSolidEdgeMiddle(direction) * (HexMetrics.innerToOuter * 0.5);
            } else if cell.hasRiverThroughEdge(direction.previous2()) {
                c += HexMetrics.getFirstSolidCorner(direction) * 0.25
            }
        } else if cell.hasRiverThroughEdge(direction.previous()) && cell.hasRiverThroughEdge(direction.next2()) {
            c += HexMetrics.getSecondSolidCorner(direction) * 0.25
        }

        let m = Edge(corner1: SCNVector3Lerp(vectorStart: c, vectorEnd: e.v1, t: 0.5),
                     corner2: SCNVector3Lerp(vectorStart: c, vectorEnd: e.v5, t: 0.5))

        triangulateEdgeStrip(e1: m, c1: Color.color1, type1: Float(cell.terrainTypeIndex),
                             e2: e, c2: Color.color1, type2: Float(cell.terrainTypeIndex))

        triangulateEdgeFan(center: c, edge: m, type: Float(cell.terrainTypeIndex))
    }

    private func triangulateWithoutRiver(direction: HexDirection, cell: HexCell, center: SCNVector3, e: Edge) {
        triangulateEdgeFan(center: center, edge: e, type: Float(cell.terrainTypeIndex))
    }

    private func triangulateEdgeFan(center: SCNVector3, edge: Edge, type: Float) {
        self.terrain.addTriangle(v1: center, v2: edge.v1, v3: edge.v2)
        self.terrain.addTriangle(v1: center, v2: edge.v2, v3: edge.v3)
        self.terrain.addTriangle(v1: center, v2: edge.v3, v3: edge.v4)
        self.terrain.addTriangle(v1: center, v2: edge.v4, v3: edge.v5)

        self.terrain.addTriangleColor(Color.color1)
        self.terrain.addTriangleColor(Color.color1)
        self.terrain.addTriangleColor(Color.color1)
        self.terrain.addTriangleColor(Color.color1)

        let types = SCNVector3(type, type, type)
        self.terrain.addTriangleTerrainTypes(types)
        self.terrain.addTriangleTerrainTypes(types)
        self.terrain.addTriangleTerrainTypes(types)
        self.terrain.addTriangleTerrainTypes(types)
    }

    private func triangulateEdgeStrip(e1: Edge, c1: Color, type1: Float, e2: Edge, c2: Color, type2: Float) {
        self.terrain.addQuad(v1: e1.v1, v2: e1.v2, v3: e2.v1, v4: e2.v2)
        self.terrain.addQuad(v1: e1.v2, v2: e1.v3, v3: e2.v2, v4: e2.v3)
        self.terrain.addQuad(v1: e1.v3, v2: e1.v4, v3: e2.v3, v4: e2.v4)
        self.terrain.addQuad(v1: e1.v4, v2: e1.v5, v3: e2.v4, v4: e2.v5)

        self.terrain.addQuadColor(c1: c1, c2: c2)
        self.terrain.addQuadColor(c1: c1, c2: c2)
        self.terrain.addQuadColor(c1: c1, c2: c2)
        self.terrain.addQuadColor(c1: c1, c2: c2)

        let types = SCNVector3(type1, type2, type1)
        self.terrain.addQuadTerrainTypes(types)
        self.terrain.addQuadTerrainTypes(types)
        self.terrain.addQuadTerrainTypes(types)
        self.terrain.addQuadTerrainTypes(types)
    }

    private func triangulateConnection(direction: HexDirection, cell: HexCell, e1: Edge) {
        guard let neighbor = cell.getNeighbor(direction) else {
            return
        }

        let bridge = HexMetrics.getBridge(direction)
        let b1 = SCNVector3(bridge.x, neighbor.position.y - cell.position.y, bridge.z)
        var e2 = Edge(corner1: e1.v1 + b1, corner2: e1.v5 + b1)

        if cell.hasRiverThroughEdge(direction) {
            e2.v3.y = neighbor.streamBedY
            let reversed = cell.hasIncomingRiver && cell.incomingRiver == direction
            triangulateRiverQuad(v1: e1.v2, v2: e1.v4, v3: e2.v2, v4: e2.v4,
                                 y1: cell.riverSurfaceY, y2: neighbor.riverSurfaceY,
                                 v: 0.8,
                                 reversed: reversed)
        }

        if cell.getEdgeType(direction) == .Slope {
            triangulateEdgeTerraces(begin: e1, beginCell: cell, end: e2, endCell: neighbor)
        } else {
            triangulateEdgeStrip(e1: e1, c1: Color.color1, type1: Float(cell.terrainTypeIndex),
                                 e2: e2, c2: Color.color2, type2: Float(neighbor.terrainTypeIndex))
        }

        if direction.rawValue <= HexDirection.E.rawValue, let next = cell.getNeighbor(direction.next()) {
            let v5 = createVertex(v1: e1.v5, v2: HexMetrics.getBridge(direction.next()), cell: next)

            if cell.elevation <= neighbor.elevation {
                if cell.elevation <= next.elevation {
                    let bottom = Corner(v: e1.v5, cell: cell)
                    let left = Corner(v: e2.v5, cell: neighbor)
                    let right = Corner(v: v5, cell: next)
                    triangulateCorner(bottom: bottom, left: left, right: right)
                } else {
                    let bottom = Corner(v: v5, cell: next)
                    let left = Corner(v: e1.v5, cell: cell)
                    let right = Corner(v: e2.v5, cell: neighbor)
                    triangulateCorner(bottom: bottom, left: left, right: right)
                }
            } else if neighbor.elevation <= next.elevation {
                let bottom = Corner(v: e2.v5, cell: neighbor)
                let left = Corner(v: v5, cell: next)
                let right = Corner(v: e1.v5, cell: cell)
                triangulateCorner(bottom: bottom, left: left, right: right)
            } else {
                let bottom = Corner(v: v5, cell: next)
                let left = Corner(v: e1.v5, cell: cell)
                let right = Corner(v: e2.v5, cell: neighbor)
                triangulateCorner(bottom: bottom, left: left, right: right)
            }
        }
    }

    // MARK: Water

    private func triangulateWater(direction: HexDirection, cell: HexCell, center: SCNVector3) {
        let c = update(v: center, y: cell.waterSurfaceY)

        if let neighbor = cell.getNeighbor(direction), !neighbor.isUnderwater {
            triangulateWaterShore(direction: direction, cell: cell, neighbor: neighbor, center: c)
        } else {
            triangulateOpenWater(direction: direction, cell: cell, neighbor: cell.getNeighbor(direction), center: c)
        }
    }

    func triangulateOpenWater(direction: HexDirection, cell: HexCell, neighbor: HexCell?, center: SCNVector3) {
        let c1 = center + HexMetrics.getFirstWaterCorner(direction)
        let c2 = center + HexMetrics.getSecondWaterCorner(direction)

        self.water.addTriangle(v1: center, v2: c1, v3: c2)

        if direction.rawValue <= HexDirection.SE.rawValue && neighbor != nil {
            let bridge = HexMetrics.getWaterBridge(direction)
            let e1 = c1 + bridge
            let e2 = c2 + bridge

            self.water.addQuad(v1: c1, v2: c2, v3: e1, v4: e2)

            if direction.rawValue <= HexDirection.E.rawValue {
                if let next = cell.getNeighbor(direction.next()), next.isUnderwater {
                    let v3 = c2 + HexMetrics.getWaterBridge(direction.next())
                    self.water.addTriangle(v1: c2, v2: e2, v3: v3)
                }
            }
        }
    }

    func triangulateWaterShore(direction: HexDirection, cell: HexCell, neighbor: HexCell, center: SCNVector3) {
        let e1 = Edge(corner1: center + HexMetrics.getFirstWaterCorner(direction),
                      corner2: center + HexMetrics.getSecondWaterCorner(direction))

        self.water.addTriangle(v1: center, v2: e1.v1, v3: e1.v2)
        self.water.addTriangle(v1: center, v2: e1.v2, v3: e1.v3)
        self.water.addTriangle(v1: center, v2: e1.v3, v3: e1.v4)
        self.water.addTriangle(v1: center, v2: e1.v4, v3: e1.v5)

        let center2 = update(v: neighbor.position, y: center.y)
        let e2 = Edge(corner1: center2 + HexMetrics.getSecondSolidCorner(direction.opposite()),
                      corner2: center2 + HexMetrics.getFirstSolidCorner(direction.opposite()))

        self.waterShore.addQuad(v1: e1.v1, v2: e1.v2, v3: e2.v1, v4: e2.v2)
        self.waterShore.addQuad(v1: e1.v2, v2: e1.v3, v3: e2.v2, v4: e2.v3)
        self.waterShore.addQuad(v1: e1.v3, v2: e1.v4, v3: e2.v3, v4: e2.v4)
        self.waterShore.addQuad(v1: e1.v4, v2: e1.v5, v3: e2.v4, v4: e2.v5)

        self.waterShore.addQuadUV(uMin: 0, uMax: 0, vMin: 0, vMax: 1)
        self.waterShore.addQuadUV(uMin: 0, uMax: 0, vMin: 0, vMax: 1)
        self.waterShore.addQuadUV(uMin: 0, uMax: 0, vMin: 0, vMax: 1)
        self.waterShore.addQuadUV(uMin: 0, uMax: 0, vMin: 0, vMax: 1)

        if let next = cell.getNeighbor(direction.next()) {
            var v3 = next.position
            if next.isUnderwater {
                v3 += HexMetrics.getFirstWaterCorner(direction.previous())
            } else {
                v3 += HexMetrics.getFirstSolidCorner(direction.previous())
            }
            v3.y = center.y
            self.waterShore.addTriangle(v1: e1.v5, v2: e2.v5, v3: v3)

            let y = next.isUnderwater ? 0 : 1
            self.waterShore.addTriangleUV(uv1: CGPoint(x: 0, y: 0),
                                          uv2: CGPoint(x: 0, y: 1),
                                          uv3: CGPoint(x: 0, y: y))
        }
    }

    private func triangulateEdgeTerraces(begin: Edge, beginCell: HexCell, end: Edge, endCell: HexCell) {
        var e2 = Edge.terraceLerp(a: begin, b: end, step: 1)
        var c2 = HexMetrics.terraceLerp(a: Color.color1, b: Color.color2, step: 1)
        let t1 = Float(beginCell.terrainTypeIndex)
        let t2 = Float(endCell.terrainTypeIndex)

        triangulateEdgeStrip(e1: begin, c1: Color.color1, type1: t1,
                             e2: e2, c2: c2, type2: t2)

        for i in 2..<HexMetrics.terraceSteps {
            let e1 = e2
            let c1 = c2

            e2 = Edge.terraceLerp(a: begin, b: end, step: i)
            c2 = HexMetrics.terraceLerp(a: Color.color1, b: Color.color2, step: i)

            triangulateEdgeStrip(e1: e1, c1: c1, type1: t1,
                                 e2: e2, c2: c2, type2: t2)
        }

        triangulateEdgeStrip(e1: e2, c1: c2, type1: t1,
                             e2: end, c2: Color.color2, type2: t2)
    }

    // MARK: Corner

    private func triangulateCorner(bottom: Corner, left: Corner, right: Corner) {
        let leftEdgeType = bottom.cell.getEdgeType(left.cell)
        let rightEdgeType = bottom.cell.getEdgeType(right.cell)

        if leftEdgeType == .Slope {
            if rightEdgeType == .Slope {
                triangulateCornerTerraces(begin: bottom, left: left, right: right)
            } else if rightEdgeType == .Flat {
                triangulateCornerTerraces(begin: left, left: right, right: bottom)
            } else {
                triangulateCornerTerracesCliff(begin: bottom, left: left, right: right)
            }
        } else if rightEdgeType == .Slope {
            if leftEdgeType == .Flat {
                triangulateCornerTerraces(begin: right, left: bottom, right: left)
            } else {
                triangulateCornerCliffTerraces(begin: bottom, left: left, right: right)
            }
        } else if left.cell.getEdgeType(right.cell) == .Slope {
            if left.cell.elevation < right.cell.elevation {
                triangulateCornerCliffTerraces(begin: right, left: bottom, right: left)
            } else {
                triangulateCornerTerracesCliff(begin: left, left: right, right: bottom)
            }
        } else {
            self.terrain.addTriangle(v1: bottom.v, v2: left.v, v3: right.v)
            self.terrain.addTriangleColor(c1: Color.color1, c2: Color.color2, c3: Color.color3)

            let types = SCNVector3(Float(bottom.cell.terrainTypeIndex),
                                   Float(left.cell.terrainTypeIndex),
                                   Float(right.cell.terrainTypeIndex))
            self.terrain.addTriangleTerrainTypes(types)
        }
    }

    private func triangulateCornerTerraces(begin: Corner, left: Corner, right: Corner) {
        var v3 = HexMetrics.terraceLerp(a: begin.v, b: left.v, step: 1)
        var v4 = HexMetrics.terraceLerp(a: begin.v, b: right.v, step: 1)
        var c3 = HexMetrics.terraceLerp(a: Color.color1, b: Color.color2, step: 1)
        var c4 = HexMetrics.terraceLerp(a: Color.color1, b: Color.color3, step: 1)
        let types = SCNVector3(Float(begin.cell.terrainTypeIndex),
                               Float(left.cell.terrainTypeIndex),
                               Float(right.cell.terrainTypeIndex))

        self.terrain.addTriangle(v1: begin.v, v2: v3, v3: v4)
        self.terrain.addTriangleColor(c1: Color.color1, c2: c3, c3: c4)
        self.terrain.addTriangleTerrainTypes(types)

        for i in 2..<HexMetrics.terraceSteps {
            let v1 = v3
            let v2 = v4
            let c1 = c3
            let c2 = c4

            v3 = HexMetrics.terraceLerp(a: begin.v, b: left.v, step: i)
            v4 = HexMetrics.terraceLerp(a: begin.v, b: right.v, step: i)
            c3 = HexMetrics.terraceLerp(a: Color.color1, b: Color.color2, step: i)
            c4 = HexMetrics.terraceLerp(a: Color.color1, b: Color.color3, step: i)

            self.terrain.addQuad(v1: v1, v2: v2, v3: v3, v4: v4)
            self.terrain.addQuadColor(c1: c1, c2: c2, c3: c3, c4: c4)
            self.terrain.addQuadTerrainTypes(types)
        }

        self.terrain.addQuad(v1: v3, v2: v4, v3: left.v, v4: right.v)
        self.terrain.addQuadColor(c1: c3, c2: c4, c3: Color.color2, c4: Color.color3)
        self.terrain.addQuadTerrainTypes(types)
    }

    private func triangulateCornerTerracesCliff(begin: Corner, left: Corner, right: Corner) {
        let b = abs(1.0 / TFloat(right.cell.elevation - begin.cell.elevation))
        let boundary = SCNVector3Lerp(vectorStart: perturb(begin.v), vectorEnd: perturb(right.v), t: b)
        let boundaryColor = ColorLerp(start: Color.color1, end: Color.color3, t: Float(b))
        let types = SCNVector3(Float(begin.cell.terrainTypeIndex),
                               Float(left.cell.terrainTypeIndex),
                               Float(right.cell.terrainTypeIndex))

        triangulateBoundaryTriangle(begin: begin, beginColor: Color.color1,
                                    left: left, leftColor: Color.color2,
                                    boundary: boundary, boundaryColor: boundaryColor,
                                    types: types)

        if left.cell.getEdgeType(right.cell) == .Slope {
            triangulateBoundaryTriangle(begin: left, beginColor: Color.color2,
                                        left: right, leftColor: Color.color3,
                                        boundary: boundary, boundaryColor: boundaryColor,
                                        types: types)
        } else {
            self.terrain.addTriangleUnperturbed(v1: perturb(left.v), v2: perturb(right.v), v3: boundary)
            self.terrain.addTriangleColor(c1: Color.color2, c2: Color.color3, c3: boundaryColor)
            self.terrain.addTriangleTerrainTypes(types)
        }
    }

    private func triangulateCornerCliffTerraces(begin: Corner, left: Corner, right: Corner) {
        let b = abs(1.0 / TFloat(left.cell.elevation - begin.cell.elevation))
        let boundary = SCNVector3Lerp(vectorStart: perturb(begin.v), vectorEnd: perturb(left.v), t: b)
        let boundaryColor = ColorLerp(start: Color.color1, end: Color.color2, t: Float(b))
        let types = SCNVector3(Float(begin.cell.terrainTypeIndex),
                               Float(left.cell.terrainTypeIndex),
                               Float(right.cell.terrainTypeIndex))

        triangulateBoundaryTriangle(begin: right, beginColor: Color.color3,
                                    left: begin, leftColor: Color.color1,
                                    boundary: boundary, boundaryColor: boundaryColor,
                                    types: types)

        if left.cell.getEdgeType(right.cell) == .Slope {
            triangulateBoundaryTriangle(begin: left, beginColor: Color.color2,
                                        left: right, leftColor: Color.color3,
                                        boundary: boundary, boundaryColor: boundaryColor,
                                        types: types)
        } else {
            self.terrain.addTriangleUnperturbed(v1: perturb(left.v), v2: perturb(right.v), v3: boundary)
            self.terrain.addTriangleColor(c1: Color.color2, c2: Color.color3, c3: boundaryColor)
            self.terrain.addTriangleTerrainTypes(types)
        }
    }

    private func triangulateBoundaryTriangle(begin: Corner, beginColor: Color,
                                             left: Corner, leftColor: Color,
                                             boundary: SCNVector3, boundaryColor: Color,
                                             types: SCNVector3) {
        var v2 = perturb(HexMetrics.terraceLerp(a: begin.v, b: left.v, step: 1))
        var c2 = HexMetrics.terraceLerp(a: beginColor, b: leftColor, step: 1)

        self.terrain.addTriangleUnperturbed(v1: perturb(begin.v), v2: v2, v3: boundary)
        self.terrain.addTriangleColor(c1: beginColor, c2: c2, c3: boundaryColor)
        self.terrain.addTriangleTerrainTypes(types)

        for i in 2..<HexMetrics.terraceSteps {
            let v1 = v2
            let c1 = c2

            v2 = perturb(HexMetrics.terraceLerp(a: begin.v, b: left.v, step: i))
            c2 = HexMetrics.terraceLerp(a: beginColor, b: leftColor, step: i)

            self.terrain.addTriangleUnperturbed(v1: v1, v2: v2, v3: boundary)
            self.terrain.addTriangleColor(c1: c1, c2: c2, c3: boundaryColor)
            self.terrain.addTriangleTerrainTypes(types)
        }

        self.terrain.addTriangleUnperturbed(v1: v2, v2: perturb(left.v), v3: boundary)
        self.terrain.addTriangleColor(c1: c2, c2: leftColor, c3: boundaryColor)
        self.terrain.addTriangleTerrainTypes(types)
    }

    private func triangulateRiverQuad(v1: SCNVector3, v2: SCNVector3, v3: SCNVector3, v4: SCNVector3, y: TFloat, v: TFloat, reversed: Bool) {
        triangulateRiverQuad(v1: v1, v2: v2, v3: v3, v4: v4, y1: y, y2: y, v: v, reversed: reversed)
    }

    private func triangulateRiverQuad(v1: SCNVector3, v2: SCNVector3, v3: SCNVector3, v4: SCNVector3, y1: TFloat, y2: TFloat, v: TFloat, reversed: Bool) {
        let t1 = update(v: v1, y: y1)
        let t2 = update(v: v2, y: y1)
        let t3 = update(v: v3, y: y2)
        let t4 = update(v: v4, y: y2)

        self.rivers.addQuad(v1: t1, v2: t2, v3: t3, v4: t4)

        if reversed {
            self.rivers.addQuadUV(uMin: 1, uMax: 0, vMin: 0.8 - v, vMax: 0.6 - v)
        } else {
            self.rivers.addQuadUV(uMin: 0, uMax: 1, vMin: v, vMax: v + 0.2)
        }
    }
}

private struct Corner {
    var v: SCNVector3
    var cell: HexCell
}

private func createVertex(v1: SCNVector3, v2: SCNVector3, cell: HexCell) -> SCNVector3 {
    var v = v1 + v2
    v.y = cell.position.y
    return v
}
