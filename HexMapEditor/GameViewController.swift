//
//  GameViewController.swift
//  HexMapEditor
//
//  Created by  Ivan Ushakov on 22/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import SceneKit
import HexMapKit

enum CellType: String, CaseIterable {
    case Ignore, Sand, Grass, Earth, Stone, Snow
}

extension CellType {
    func index() -> Int {
        guard let index = CellType.allCases.firstIndex(of: self) else {
            fatalError()
        }
        return index - 1
    }
}

enum RiverType: String, CaseIterable {
    case Ignore, Yes, No
}

class GameViewModel {
    let cellType = Variable<CellType>(CellType.Sand)
    let useElevation = Variable<Bool>(false)
    let elevation = Variable<Int>(0)
    let useWaterLevel = Variable<Bool>(false)
    let waterLevel = Variable<Int>(0)
    let river = Variable<RiverType>(RiverType.Ignore)
    let brush = Variable<Int>(0)
}

class GameViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var sceneView: SCNView!
    
    private let grid = HexGrid()
    private let camera = Camera()
    
    private let viewModel = GameViewModel()
    
    private var previousCell: HexCoordinates? = nil
    private var isDrag = false
    private var dragDirection = HexDirection.NE
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()

        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.collectionView.register(CellViewItem.self, forItemWithIdentifier: CellViewItem.identifier)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.grid.start()
    }
    
    override func mouseDown(with event: NSEvent) {
        handleMouse(event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        handleMouse(event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        self.camera.adjustZoom(delta: Float(0.01 * event.scrollingDeltaY))
    }
    
    override func keyDown(with event: NSEvent) {
        guard let c1 = event.characters?.first?.unicodeScalars.first else {
            return
        }
        
        let delta = CGFloat(0.5)
        
        switch Int(c1.value) {
        case NSLeftArrowFunctionKey:
            self.camera.adjustPosition(x: -delta, y: 0)
            break
            
        case NSRightArrowFunctionKey:
            self.camera.adjustPosition(x: delta, y: 0)
            break
            
        case NSDownArrowFunctionKey:
            self.camera.adjustPosition(x: 0, y: delta)
            break
            
        case NSUpArrowFunctionKey:
            self.camera.adjustPosition(x: 0, y: -delta)
            break
            
        default:
            break
        }
    }
    
    private func setupScene() {
        self.sceneView.scene = SCNScene()
        self.sceneView.scene?.rootNode.addChildNode(self.grid.node)
        self.sceneView.scene?.rootNode.addChildNode(self.camera.node)
        self.sceneView.backgroundColor = NSColor(white: 0.5, alpha: 1.0)
        
        let light = SCNLight()
        light.type = .directional
        
        let lightNode = SCNNode()
        lightNode.name = "DirectionalLight"
        lightNode.light = light
        lightNode.position = SCNVector3(x: 0, y: 250, z: 0)
        self.sceneView.scene?.rootNode.addChildNode(lightNode)
        
        self.sceneView.rendersContinuously = true
    }
    
    private func handleMouse(_ event: NSEvent) {
        let location = self.sceneView.convert(event.locationInWindow, from: nil)
        let result = self.sceneView.hitTest(location, options: nil)
        
        if let position = result.first?.localCoordinates {
            let currentCell = self.grid.getCoordinates(position)
            
            if self.previousCell != nil && self.previousCell != currentCell {
                validateDrag(currentCell)
            } else {
                self.isDrag = false
            }
            
            editCells(currentCell)
            
            self.previousCell = currentCell
            self.isDrag = true
        } else {
            self.previousCell = nil
        }
    }
    
    private func validateDrag(_ currentCell: HexCoordinates) {
        if let from = self.previousCell, let direction = self.grid.findDirection(from: from, to: currentCell) {
            self.dragDirection = direction
            self.isDrag = true
        } else {
            self.isDrag = false
        }
    }
    
    private func editCells(_ coordinates: HexCoordinates) {
        let brush = self.viewModel.brush.value
        
        if brush == 0 {
            editCell(coordinates)
            return
        }
        
        let centerX = coordinates.x
        let centerZ = coordinates.z
        
        for i in 0...brush {
            let start = centerX - brush
            let end = centerX + brush - i
            for x in start...end {
                editCell(HexCoordinates(x: x, z: centerZ + i))
            }
        }
        
        for i in 1...brush {
            let start = centerX - brush + i
            let end = centerX + brush
            for x in start...end {
                editCell(HexCoordinates(x: x, z: centerZ - i))
            }
        }
    }
    
    private func editCell(_ coordinates: HexCoordinates) {
        let cellType = self.viewModel.cellType.value
        if cellType != .Ignore {
            self.grid.setCellTerrainTypeIndex(coordinates: coordinates, terrainTypeIndex: cellType.index())
        }
        
        if self.viewModel.useElevation.value {
            self.grid.setCellElevation(coordinates: coordinates, elevation: self.viewModel.elevation.value)
        }
        
        if self.viewModel.useWaterLevel.value {
            self.grid.setCellWaterLevel(coordinates: coordinates, waterLevel: self.viewModel.waterLevel.value)
        }
        
        let riverMode = self.viewModel.river.value
        if riverMode == .No {
            self.grid.removeRiver(coordinates)
        } else {
            if self.isDrag && riverMode == .Yes {
                guard let coordinates = self.previousCell else { return }
                self.grid.setOutgoindRiver(coordinates: coordinates, direction: self.dragDirection)
            }
        }
        
        self.grid.start()
    }
}

extension GameViewController {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: CellViewItem.identifier, for: indexPath) as? CellViewItem else {
            fatalError()
        }
        
        item.bindModel(self.viewModel)
        
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let width = collectionView.bounds.width
        return CGSize(width: width, height: 240)
    }
}

class CellViewItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("CellViewItem")
    
    private let contentView = NSStackView()
    
    private var colorButton: MenuButton<CellType>? = nil
    private var elevationButton: CheckButton? = nil
    private var elevationSlider: Slider? = nil
    private var waterLevelButton: CheckButton? = nil
    private var waterLevelSlider: Slider? = nil
    private var riverButton: MenuButton<RiverType>? = nil
    private var brushSlider: Slider? = nil
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        self.contentView.orientation = .vertical
        self.contentView.distribution = .fillEqually
        self.contentView.edgeInsets = NSEdgeInsetsMake(5, 5, 5, 5)
        
        var views = [NSView]()
        
        views.append(createLabel("Terrain"))
        let b1 = NSPopUpButton()
        b1.addItems(withTitles: CellType.allCases.map { $0.rawValue })
        views.append(b1)
        self.colorButton = MenuButton<CellType>(values: CellType.allCases, control: b1)
        
        let b2 = NSButton()
        b2.title = "Elevation"
        b2.setButtonType(.switch)
        views.append(b2)
        self.elevationButton = CheckButton(control: b2)
        
        let s1 = NSSlider()
        s1.minValue = 0
        s1.maxValue = 6
        views.append(s1)
        self.elevationSlider = Slider(control: s1)
        
        let b3 = NSButton()
        b3.title = "Water"
        b3.setButtonType(.switch)
        views.append(b3)
        self.waterLevelButton = CheckButton(control: b3)
        
        let s2 = NSSlider()
        s2.minValue = 0
        s2.maxValue = 6
        views.append(s2)
        self.waterLevelSlider = Slider(control: s2)
        
        views.append(createLabel("River"))
        let b4 = NSPopUpButton()
        b4.addItems(withTitles: RiverType.allCases.map { $0.rawValue })
        views.append(b4)
        self.riverButton = MenuButton(values: RiverType.allCases, control: b4)
        
        views.append(createLabel("Brush"))
        let s3 = NSSlider()
        s3.minValue = 0
        s3.maxValue = 4
        views.append(s3)
        self.brushSlider = Slider(control: s3)
        
        self.contentView.setViews(views, in: .top)
    }
    
    override func loadView() {
        self.view = self.contentView
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    func bindModel(_ viewModel: GameViewModel) {
        self.colorButton?.variable = viewModel.cellType
        self.elevationButton?.variable = viewModel.useElevation
        self.elevationSlider?.variable = viewModel.elevation
        self.waterLevelButton?.variable = viewModel.useWaterLevel
        self.waterLevelSlider?.variable = viewModel.waterLevel
        self.riverButton?.variable = viewModel.river
        self.brushSlider?.variable = viewModel.brush
    }
    
    private func createLabel(_ title: String) -> NSTextView {
        let label = NSTextView()
        label.isEditable = false
        label.alignment = .center
        label.string = title
        return label
    }
}
