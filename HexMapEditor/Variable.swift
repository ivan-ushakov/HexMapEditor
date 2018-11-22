//
//  Variable.swift
//  HexMapEditor
//
//  Created by  Ivan Ushakov on 30/11/2018.
//  Copyright © 2018  Ivan Ushakov. All rights reserved.
//

import AppKit

public class Variable<T> {
    
    var value: T
    
    init(_ value: T) {
        self.value = value
    }
}

public class MenuButton<T> {
    let values: [T]
    let control: NSPopUpButton
    
    var variable: Variable<T>? = nil
    
    init(values: [T], control: NSPopUpButton) {
        self.values = values
        self.control = control
        
        control.target = self
        control.action = #selector(MenuButton.handle)
    }
    
    @objc func handle() {
        self.variable?.value = self.values[self.control.indexOfSelectedItem]
    }
}

public class CheckButton {
    let control: NSButton
    
    var variable: Variable<Bool>? = nil
    
    init(control: NSButton) {
        self.control = control
        
        control.target = self
        control.action = #selector(CheckButton.handle)
    }
    
    @objc func handle() {
        self.variable?.value = self.control.state == .on
    }
}

public class Slider {
    let control: NSSlider
    
    var variable: Variable<Int>? = nil
    
    init(control: NSSlider) {
        self.control = control
        
        control.target = self
        control.action = #selector(Slider.handle)
    }
    
    @objc func handle() {
        self.variable?.value = self.control.integerValue
    }
}
