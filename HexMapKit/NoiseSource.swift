//
//  NoiseSource.swift
//  HexMapKit
//
//  Created by  Ivan Ushakov on 11/12/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import GameplayKit

class NoiseSource {
    
    static let shared = NoiseSource()
    
    private let m1: GKNoiseMap
    private let m2: GKNoiseMap
    private let m3: GKNoiseMap
    
    private init() {
        let source = GKPerlinNoiseSource()
        let noise = GKNoise(source)
        
        let size = vector2(16.0, 16.0)
        let origin = vector2(0.0, 0.0)
        
        self.m1 = GKNoiseMap(noise, size: size, origin: origin, sampleCount: vector_int2(512), seamless: true)
        self.m2 = GKNoiseMap(noise, size: size, origin: origin, sampleCount: vector_int2(512), seamless: true)
        self.m3 = GKNoiseMap(noise, size: size, origin: origin, sampleCount: vector_int2(512), seamless: true)
    }
    
    func get(_ position: SCNVector3) -> SCNVector3 {
        let n = position * 0.003
        return get(Float(n.x), Float(n.z))
    }
    
    func get(_ u: Float, _ v: Float) -> SCNVector3 {
        let p = vector_int2(Int32(512.0 * u), Int32(512.0 * v))
        
        let x = self.m1.value(at: p)
        let y = self.m2.value(at: p)
        let z = self.m3.value(at: p)
        
        return SCNVector3(x, y, z)
    }
}

func perturb(_ position: SCNVector3) -> SCNVector3 {
    let sample = NoiseSource.shared.get(position)
    
    let x = position.x + sample.x * HexMetrics.cellPerturbStrength
    let z = position.z + sample.z * HexMetrics.cellPerturbStrength
    
    return SCNVector3(x, position.y, z)
}
