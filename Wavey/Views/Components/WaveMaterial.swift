//
//  WaveMaterial.swift
//  Wavey
//
//  Created by Reza Ali on 10/11/22.
//

import Foundation
import Satin

class WaveMaterial: LiveMaterial {
    override init(pipelinesURL: URL) {
        super.init(pipelinesURL: pipelinesURL)
        set("Amplitude", 0.175)
        set("Frequency", 16.0)
        set("Speed", 4.0)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
}

