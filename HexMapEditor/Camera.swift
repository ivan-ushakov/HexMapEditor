//
//  Camera.swift
//  HexMapEditor
//
//  Created by  Ivan Ushakov on 24/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import SceneKit

public class Camera: SCNNode {
    
    public let node = SCNNode()
    
    var zoom = Float(1)
    
    var stickMinZoom = Float(250)
    var stickMaxZoom = Float(45)
    
    private let swivel = SCNNode()
    private let stick = SCNNode()
    
    public override init() {
        super.init()
        
        self.stick.camera = SCNCamera()
        self.stick.camera?.automaticallyAdjustsZRange = true
        self.stick.position = SCNVector3(0, 0, 45)
        self.swivel.addChildNode(self.stick)
        
        self.swivel.eulerAngles = SCNVector3(-45 * Float.pi / 180, 0, 0)
        self.node.addChildNode(self.swivel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    public func adjustZoom(delta: Float) {
        self.zoom = clamp(float2(self.zoom + delta), min: Float(0.0), max: Float(1.0)).x
        
        let distance = self.stickMinZoom + (self.stickMaxZoom - stickMinZoom) * self.zoom
        self.stick.position = SCNVector3(0, 0, distance)
    }
    
    public func adjustPosition(x: CGFloat, y: CGFloat) {
        let p = SCNVector3(x: x, y: 0, z: y)
        self.node.position += p
    }
}
