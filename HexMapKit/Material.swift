//
//  Material.swift
//  HexMapKit
//
//  Created by  Ivan Ushakov on 30/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import SceneKit
import MetalKit

class MaterialFactory {
    
    static let shared = MaterialFactory()
    
    let riverMaterial = SCNMaterial()
    let waterMaterial = SCNMaterial()
    let waterShoreMaterial = SCNMaterial()
    
    private let noiseTexture: MTLTexture
    private let terrainTexture: MTLTexture
    private let gridTexture: MTLTexture
    
    private let terrainProgram = SCNProgram()
    
    func createTerrainMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.program = self.terrainProgram
        material.setValue(SCNMaterialProperty(contents: self.terrainTexture), forKey: "terrainTexture")
        material.setValue(SCNMaterialProperty(contents: self.gridTexture), forKey: "gridTexture")
        return material
    }
    
    private init() {
        guard let bundle = Bundle(identifier: "com.lunarkey.HexMapKit") else {
            fatalError()
        }
        
        self.noiseTexture = loadNoiseTexture(bundle)
        self.terrainTexture = loadTerrainTexture(bundle)
        self.gridTexture = loadGridTexture(bundle)
        
        guard let library = getLibrary(bundle) else {
            fatalError()
        }
        
        setupTerrainProgram(library: library, bundle: bundle)
        setupRiverMaterial(library: library)
        setupWaterMaterial(library: library)
        setupWaterShoreMaterial(library: library)
    }
    
    private func setupTerrainProgram(library: MTLLibrary, bundle: Bundle) {
        self.terrainProgram.isOpaque = true
        self.terrainProgram.vertexFunctionName = "terrainVertex"
        self.terrainProgram.fragmentFunctionName = "terrainFragment"
        self.terrainProgram.library = library
    }
    
    private func setupRiverMaterial(library: MTLLibrary) {
        let program = SCNProgram()
        program.isOpaque = false
        program.vertexFunctionName = "riverVertex"
        program.fragmentFunctionName = "riverFragment"
        program.library = library
        
        self.riverMaterial.program = program
        setNoiseTexture(self.riverMaterial)
    }
    
    private func setupWaterMaterial(library: MTLLibrary) {
        let program = SCNProgram()
        program.isOpaque = false
        program.vertexFunctionName = "waterVertex"
        program.fragmentFunctionName = "waterFragment"
        program.library = library
        
        self.waterMaterial.program = program
        setNoiseTexture(self.waterMaterial)
    }
    
    private func setupWaterShoreMaterial(library: MTLLibrary) {
        let program = SCNProgram()
        program.isOpaque = false
        program.vertexFunctionName = "waterShoreVertex"
        program.fragmentFunctionName = "waterShoreFragment"
        program.library = library
        
        self.waterShoreMaterial.program = program
        setNoiseTexture(self.waterShoreMaterial)
    }

    private func setNoiseTexture(_ material: SCNMaterial) {
        material.setValue(SCNMaterialProperty(contents: self.noiseTexture), forKey: "noiseTexture")
    }

    private func getLibrary(_ bundle: Bundle) -> MTLLibrary? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        
        do {
            return try device.makeDefaultLibrary(bundle: bundle)
        } catch {
            return nil
        }
    }
}

func loadNoiseTexture(_ bundle: Bundle) -> MTLTexture {
    guard let url = bundle.url(forResource: "noise", withExtension: "png") else {
        fatalError()
    }

    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError()
    }
    
    let loader = MTKTextureLoader(device: device)
    do {
        let options: [MTKTextureLoader.Option : Any] = [MTKTextureLoader.Option.SRGB: NSNumber(booleanLiteral: false)]
        return try loader.newTexture(URL: url, options: options)
    } catch {
        fatalError()
    }
}

func loadTerrainTexture(_ bundle: Bundle) -> MTLTexture {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError()
    }
    
    let names = ["sand", "grass", "earth", "stone", "snow"]
    
    let loader = MTKTextureLoader(device: device)
    let array = names.map { name -> MTLTexture in
        do {
            return try loader.newTexture(name: name, scaleFactor: 1.0, bundle: bundle, options: nil)
        } catch {
            fatalError()
        }
    }
    
    guard let queue = device.makeCommandQueue() else {
        fatalError()
    }
    guard let commandBuffer = queue.makeCommandBuffer() else {
        fatalError()
    }
    guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
        fatalError()
    }
    
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = .type2DArray
    descriptor.pixelFormat = array[0].pixelFormat
    descriptor.width = array[0].width
    descriptor.height = array[0].height
    descriptor.mipmapLevelCount = array[0].mipmapLevelCount
    descriptor.arrayLength = names.count
    
    guard let texture = device.makeTexture(descriptor: descriptor) else {
        fatalError()
    }
    
    var slice = 0
    array.forEach { item in
        for i in 0..<descriptor.mipmapLevelCount {
            let width = max(1, item.width >> i)
            let height = max(1, item.height >> i)
            let sourceSize = MTLSize(width: width, height: height, depth: 1)
            encoder.copy(from: item,
                         sourceSlice: 0,
                         sourceLevel: i,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: sourceSize,
                         to: texture,
                         destinationSlice: slice,
                         destinationLevel: i,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        }
        
        slice += 1
    }
    
    encoder.endEncoding()
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    return texture
}

func loadGridTexture(_ bundle: Bundle) -> MTLTexture {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError()
    }

    let loader = MTKTextureLoader(device: device)
    do {
        return try loader.newTexture(name: "grid", scaleFactor: 1.0, bundle: bundle, options: nil)
    } catch {
        fatalError()
    }
}
