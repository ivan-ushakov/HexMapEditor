//
//  HexMesh.swift
//  HexMapKit
//
//  Created by  Ivan Ushakov on 24/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import SceneKit
import GameplayKit

enum HexMeshType {
    case terrain, rivers, water, waterShore
}

class HexMesh {
    
    let node = SCNNode()
    
    var useColors = false
    var useTextureCoordinates = false
    var useTerrainTypes = false
    
    private let type: HexMeshType
    
    private var vertices = [SCNVector3]()
    private var normals = [SCNVector3]()
    private var triangles = [UInt16]()
    private var colors = [Color]()
    private var textureCoordinates = [CGPoint]()
    private var terrainTypes = [SCNVector3]()
    
    init(_ type: HexMeshType) {
        self.type = type

        self.node.name = "HexMesh"
    }
    
    func clear() {
        self.vertices.removeAll()
        self.normals.removeAll()
        self.triangles.removeAll()
        self.colors.removeAll()
        self.textureCoordinates.removeAll()
        self.terrainTypes.removeAll()
    }
    
    func apply() {
        var sources = [SCNGeometrySource]()
        
        sources.append(SCNGeometrySource(vertices: self.vertices))
        
        recalculateNormals()
        sources.append(SCNGeometrySource(normals: self.normals))
        
        if self.useColors {
            let data = Data(bytes: self.colors, count: MemoryLayout<Color>.stride * self.colors.count)
            let colorSource = SCNGeometrySource(data: data,
                                                semantic: .color,
                                                vectorCount: self.vertices.count,
                                                usesFloatComponents: true,
                                                componentsPerVector: 3,
                                                bytesPerComponent: MemoryLayout<Float>.size,
                                                dataOffset: 0,
                                                dataStride: MemoryLayout<Color>.stride)
            sources.append(colorSource)
        }
        
        if self.useTextureCoordinates {
            sources.append(SCNGeometrySource(textureCoordinates: self.textureCoordinates))
        }
        
        let element = SCNGeometryElement(indices: self.triangles, primitiveType: .triangles)
        self.node.geometry = SCNGeometry(sources: sources, elements: [element])
        
        applyMaterial()
    }
    
    func addTriangle(v1: SCNVector3, v2: SCNVector3, v3: SCNVector3) {
        // TODO don't perturb vertices for now
        addTriangleUnperturbed(v1: v1, v2: v2, v3: v3)
    }
    
    func addTriangleUnperturbed(v1: SCNVector3, v2: SCNVector3, v3: SCNVector3) {
        let last = self.vertices.count
        
        self.vertices.append(v1)
        self.vertices.append(v2)
        self.vertices.append(v3)
        
        self.triangles.append(UInt16(last))
        self.triangles.append(UInt16(last + 1))
        self.triangles.append(UInt16(last + 2))
    }
    
    func addTriangleColor(_ color: Color) {
        self.colors.append(color)
        self.colors.append(color)
        self.colors.append(color)
    }
    
    func addTriangleColor(c1: Color, c2: Color, c3: Color) {
        self.colors.append(c1)
        self.colors.append(c2)
        self.colors.append(c3)
    }
    
    func addTriangleUV(uv1: CGPoint, uv2: CGPoint, uv3: CGPoint) {
        self.textureCoordinates.append(uv1)
        self.textureCoordinates.append(uv2)
        self.textureCoordinates.append(uv3)
    }
    
    func addTriangleTerrainTypes(_ types: SCNVector3) {
        self.terrainTypes.append(types)
        self.terrainTypes.append(types)
        self.terrainTypes.append(types)
    }
    
    func addQuad(v1: SCNVector3, v2: SCNVector3, v3: SCNVector3, v4: SCNVector3) {
        let last = self.vertices.count
        
        self.vertices.append(v1)
        self.vertices.append(v2)
        self.vertices.append(v3)
        self.vertices.append(v4)
        
        self.triangles.append(UInt16(last))
        self.triangles.append(UInt16(last + 2))
        self.triangles.append(UInt16(last + 1))
        self.triangles.append(UInt16(last + 1))
        self.triangles.append(UInt16(last + 2))
        self.triangles.append(UInt16(last + 3))
    }
    
    func addQuadColor(c1: Color, c2: Color, c3: Color, c4: Color) {
        self.colors.append(c1)
        self.colors.append(c2)
        self.colors.append(c3)
        self.colors.append(c4)
    }
    
    func addQuadColor(c1: Color, c2: Color) {
        self.colors.append(c1)
        self.colors.append(c1)
        self.colors.append(c2)
        self.colors.append(c2)
    }
    
    func addQuadColor(_ color: Color) {
        self.colors.append(color)
        self.colors.append(color)
        self.colors.append(color)
        self.colors.append(color)
    }
    
    func addQuadUV(uv1: CGPoint, uv2: CGPoint, uv3: CGPoint, uv4: CGPoint) {
        self.textureCoordinates.append(uv1)
        self.textureCoordinates.append(uv2)
        self.textureCoordinates.append(uv3)
        self.textureCoordinates.append(uv4)
    }
    
    func addQuadUV(uMin: CGFloat, uMax: CGFloat, vMin: CGFloat, vMax: CGFloat) {
        self.textureCoordinates.append(CGPoint(x: uMin, y: vMin))
        self.textureCoordinates.append(CGPoint(x: uMax, y: vMin))
        self.textureCoordinates.append(CGPoint(x: uMin, y: vMax))
        self.textureCoordinates.append(CGPoint(x: uMax, y: vMax))
    }
    
    func addQuadTerrainTypes(_ types: SCNVector3) {
        self.terrainTypes.append(types)
        self.terrainTypes.append(types)
        self.terrainTypes.append(types)
        self.terrainTypes.append(types)
    }
    
    private func recalculateNormals() {
        self.normals.reserveCapacity(self.vertices.count)
        for _ in 0..<self.vertices.count {
            self.normals.append(SCNVector3Zero)
        }
        
        let numberOfFaces = self.triangles.count / 3
        for i in 0..<numberOfFaces {
            let a = Int(self.triangles[3 * i])
            let b = Int(self.triangles[3 * i + 1])
            let c = Int(self.triangles[3 * i + 2])
            
            let e1 = self.vertices[a] - self.vertices[b]
            let e2 = self.vertices[c] - self.vertices[b]
            let n = SCNVector3CrossProduct(left: e2, right: e1)
            
            self.normals[a] += n
            self.normals[b] += n
            self.normals[c] += n
        }
        
        for i in 0..<self.normals.count {
            self.normals[i] = SCNVector3Normalize(vector: self.normals[i])
        }
    }
    
    private func applyMaterial() {
        switch self.type {
        case .terrain:
            setTerrainMaterial()
            break
            
        case .rivers:
            setRiverMaterial()
            break
            
        case .water:
            setWaterMaterial()
            break
            
        case .waterShore:
            setWaterShoreMaterial()
            break
        }
    }
    
    private func setTerrainMaterial() {
        let material = MaterialFactory.shared.createTerrainMaterial()
        
        setTerrain(material)
        setLightSource(material)
        
        self.node.geometry?.materials = [material]
    }
    
    private func setTerrain(_ material: SCNMaterial) {
        let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: self.terrainTypes.count * 3)
        defer {
            buffer.deallocate()
        }
        
        self.terrainTypes.enumerated().forEach { i, v in
            buffer[i * 3 + 0] = Float(v.x)
            buffer[i * 3 + 1] = Float(v.y)
            buffer[i * 3 + 2] = Float(v.z)
        }
        
        material.setValue(Data(buffer: buffer), forKey: "terrain")
    }
    
    private func setLightSource(_ material: SCNMaterial) {
        var root: SCNNode? = self.node
        while root?.parent != nil {
            root = root?.parent
        }
        
        guard let lightNode = root?.childNode(withName: "DirectionalLight", recursively: true) else {
            fatalError()
        }
        
        let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: 3)
        defer {
            buffer.deallocate()
        }
        
        buffer[0] = Float(lightNode.position.x)
        buffer[1] = Float(lightNode.position.y)
        buffer[2] = Float(lightNode.position.z)
        
        material.setValue(Data(buffer: buffer), forKey: "light")
    }
    
    private func setRiverMaterial() {
        self.node.geometry?.materials = [MaterialFactory.shared.riverMaterial]
    }
    
    private func setWaterMaterial() {
        self.node.geometry?.materials = [MaterialFactory.shared.waterMaterial]
    }
    
    private func setWaterShoreMaterial() {
        self.node.geometry?.materials = [MaterialFactory.shared.waterShoreMaterial]
    }
}
