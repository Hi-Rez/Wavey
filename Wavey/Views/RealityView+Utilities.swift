//
//  RealityView+Utilities.swift
//  Wavey
//
//  Created by Reza Ali on 10/11/22.
//

import Foundation
import Metal

extension RealityView {
    func createTexture(_ label: String,
                       _ width: Int,
                       _ height: Int,
                       _ pixelFormat: MTLPixelFormat,
                       _ device: MTLDevice,
                       _ usage: MTLTextureUsage = [.renderTarget, .shaderRead, .shaderWrite],
                       _ storageMode: MTLStorageMode = .private,
                       _ resourceOptions: MTLResourceOptions = .storageModePrivate) -> MTLTexture?
    {
        guard width > 0, height > 0 else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.sampleCount = 1
        descriptor.textureType = .type2D
        descriptor.usage = usage
        descriptor.storageMode = .private
        descriptor.resourceOptions = resourceOptions
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.label = label
        return texture
    }
}
