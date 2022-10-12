//
//  RealityKit+Camera.swift
//  Wavey
//
//  Created by Reza Ali on 10/11/22.
//

import ARKit
import Foundation
import Metal
import Satin

extension RealityView {
    // MARK: - Camera

    func updateCamera() {
        guard let frame = session.currentFrame else { return }
        updateCameraTextures(frame)
        if cameraGeometryNeedsUpdate {
            updateCameraGeometry(frame)
            cameraGeometryNeedsUpdate = false
        }
    }

    func setupCameraTextureCache(device: MTLDevice) {
        // Create captured image texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedImageTextureCache = textureCache
    }

    func createCameraTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }

    func updateCameraGeometry(_ frame: ARFrame) {
        // Update the texture coordinates of our image plane to aspect fill the viewport
        guard let orientation = orientation else { return }
        let currentDisplayTransform = frame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()

        let geo = QuadGeometry()
        for (index, vertex) in geo.vertexData.enumerated() {
            let uv = vertex.uv
            let textureCoord = CGPoint(x: CGFloat(uv.x), y: CGFloat(uv.y))
            let transformedCoord = textureCoord.applying(currentDisplayTransform)
            geo.vertexData[index].uv = simd_make_float2(Float(transformedCoord.x), Float(transformedCoord.y))
        }
        cameraMesh.geometry = geo
    }

    func updateCameraTextures(_ frame: ARFrame) {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage
        if CVPixelBufferGetPlaneCount(pixelBuffer) < 2 {
            return
        }

        capturedImageTextureY = createCameraTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = createCameraTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
    }
}
