//
//  RealityView+Depth.swift
//  Wavey
//
//  Created by Reza Ali on 10/11/22.
//

import ARKit
import Foundation
import Metal
import RealityKit

extension RealityView {
    // MARK: - Depth
        
    func updateDepthTexture(context: ARView.PostProcessContext) {
        guard let frame = session.currentFrame else { return }
        if let depthMap = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap {
            if let depthTexturePixelFormat = setMTLPixelFormat(basedOn: depthMap) {
                capturedDepthTexture = createDepthTexture(fromPixelBuffer: depthMap, pixelFormat: depthTexturePixelFormat, planeIndex: 0)
            }
        }
    }
    
    func setupDepthTextureCache(device: MTLDevice) {
        // Create captured image texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedDepthTextureCache = textureCache
    }
    
    func createDepthTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedDepthTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
}
