//
//  RealityView+Satin.swift
//  Really
//
//  Created by Reza Ali on 7/19/22.
//

import ARKit
import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders
import ModelIO
import RealityKit
import Satin
import simd

extension RealityView {
    func getOrientation() -> UIInterfaceOrientation? {
        return window?.windowScene?.interfaceOrientation
    }
    
    func setupSatin(device: MTLDevice) {
        setupWaveMesh()
        setupScene()
        setupCameraTextureCache(device: device)
        setupDepthTextureCache(device: device)
    }
    
    func setupWaveMesh() {
        let material = WaveMaterial(pipelinesURL: pipelinesURL)
        material.onUpdate = { [weak self] in
            guard let self = self, let frame = self.session.currentFrame, let orientation = self.orientation else { return }
            let orientationTransform = frame.displayTransform(for: orientation, viewportSize: self.viewportSize).inverted()
            material.set("Orientation Transform", simd_float2x2(
                .init(Float(orientationTransform.a), Float(orientationTransform.b)),
                .init(Float(orientationTransform.c), Float(orientationTransform.d))
            ))
            material.set("Orientation Offset", simd_make_float2(Float(orientationTransform.tx), Float(orientationTransform.ty)))
            material.updateUniforms()
        }

        material.onBind = { [weak self] (renderEncoder: MTLRenderCommandEncoder) in
            guard let self = self, let cvDepthTexture = self.capturedDepthTexture, let cameraTexture = self.cameraTexture else { return }
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cvDepthTexture), index: FragmentTextureIndex.Custom0.rawValue)
            renderEncoder.setFragmentTexture(cameraTexture, index: FragmentTextureIndex.Custom1.rawValue)
        }
        
        satinWaveyMesh = Mesh(geometry: PlaneGeometry(size: 1, res: 100), material: material)
//        satinWaveyMesh.triangleFillMode = .lines
        satinWaveyMesh.orientation = simd_quatf(angle: -Float.pi * 0.5, axis: Satin.worldRightDirection)
        satinMeshContainer.add(satinWaveyMesh)
        satinMeshContainer.visible = false
    }
    
    func setupScene() {
//        let geo = CapsuleGeometry(size: (0.005, 0.2), axis: .z)
//        var geoData = geo.getGeometryData()
//        transformGeometryData(&geoData, translationMatrixf(0.0, 0.0, 0.1))
//        let xAxisMesh = Mesh(geometry: geo, material: BasicColorMaterial(.init(1.0, 0.0, 0.0, 1.0)))
//        xAxisMesh.orientation = simd_quatf(angle: Float.pi * 0.5, axis: Satin.worldUpDirection)
//        let yAxisMesh = Mesh(geometry: geo, material: BasicColorMaterial(.init(0.0, 1.0, 0.0, 1.0)))
//        yAxisMesh.orientation = simd_quatf(angle: -Float.pi * 0.5, axis: Satin.worldRightDirection)
//        let zAxisMesh = Mesh(geometry: geo, material: BasicColorMaterial(.init(0.0, 0.0, 1.0, 1.0)))
//        satinAxis.add(Mesh(geometry: IcoSphereGeometry(radius: 0.015, res: 1), material: BasicColorMaterial()))
//        satinAxis.add(xAxisMesh)
//        satinAxis.add(yAxisMesh)
//        satinAxis.add(zAxisMesh)
//        satinMeshContainer.add(satinAxis)
        
        satinMeshContainer.onUpdate = { [weak containerAnchor, weak satinMeshContainer] in
            guard let mesh = satinMeshContainer, let containerAnchor = containerAnchor else { return }
            mesh.localMatrix = containerAnchor.transform
        }
        
        satinScene.add(satinMeshContainer)
    }
    
    func setupRenderer(_ context: Context) {
        satinRenderer = Renderer(context: context, scene: satinScene, camera: satinCamera)
        satinRenderer.setClearColor(.zero)
        satinRenderer.colorLoadAction = .load
        satinRenderer.depthLoadAction = .clear
    }
    
    func setupCameraRenderer(_ context: Context) {
        cameraRenderer = Satin.Renderer(context: context, scene: cameraMesh, camera: OrthographicCamera())
        cameraRenderer.label = "Camera Renderer"
    }
        
    func updateSatinContext(context: ARView.PostProcessContext) {
        if _updateContext {
            let satinRendererContext = Context(context.device, 1, context.compatibleTargetTexture!.pixelFormat, .depth32Float)
            setupRenderer(satinRendererContext)
            
            let cameraContext = Context(context.device, 1, context.compatibleTargetTexture!.pixelFormat)
            setupCameraRenderer(cameraContext)
            
            _updateContext = false
        }
    }
    
    func setMTLPixelFormat(basedOn pixelBuffer: CVPixelBuffer!) -> MTLPixelFormat? {
        if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32 {
            return .r32Float
        } else if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_OneComponent8 {
            return .r8Uint
        } else {
            return nil
        }
    }
    
    func updateSize(context: ARView.PostProcessContext) {
        let width = context.sourceColorTexture.width
        let height = context.sourceColorTexture.height
        let size = (Float(width), Float(height))
        
        viewportSize = CGSizeMake(CGFloat(width), CGFloat(height))
        
        // because we don't need a full size render because we are going to blur it
        satinRenderer.resize(size)
        
        // this will composite our textures with a bloom material / shader
        cameraRenderer.resize(size)
    }
    
    func updateSatinCamera(context: ARView.PostProcessContext) {
        satinCamera.viewMatrix = arView.cameraTransform.matrix.inverse
        satinCamera.projectionMatrix = context.projection
        satinCamera.updateProjectionMatrix = false
        satinScene.visible = true
    }
    
    func updateTextures(context: ARView.PostProcessContext) {
        let width = context.targetColorTexture.width
        let height = context.targetColorTexture.height
        
        let pixelFormat = context.compatibleTargetTexture!.pixelFormat
        if cameraTexture == nil {
            cameraTexture = createTexture("Camera Texture", width, height, pixelFormat, context.device)
        } else if let cameraTexture = cameraTexture, cameraTexture.width != width || cameraTexture.height != height {
            self.cameraTexture = createTexture("Camera Texture", width, height, pixelFormat, context.device)
        }
    }
    
    func updateSatin(context: ARView.PostProcessContext) {
        updateSatinContext(context: context)
        updateTextures(context: context)
        updateDepthTexture(context: context)
        updateSize(context: context)
        updateSatinCamera(context: context)
        
        updateCamera()
        
        satinWaveyMesh.material?.set("Time", Float(context.time))
        
        if let model = modelEntity {
            let worldTransform = model.convert(transform: model.transform, to: nil)
            satinMeshContainer.localMatrix = worldTransform.matrix
        }
        
        let commandBuffer = context.commandBuffer
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blitEncoder?.endEncoding()
                
        if let cameraTexture = cameraTexture {
            cameraRenderer.draw(renderPassDescriptor: MTLRenderPassDescriptor(), commandBuffer: commandBuffer, renderTarget: cameraTexture)
        }
        
        let targetColorTexture = context.compatibleTargetTexture!
        
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = targetColorTexture
//        rpd.depthAttachment.texture = context.sourceDepthTexture

        satinRenderer.draw(
            renderPassDescriptor: rpd,
            commandBuffer: commandBuffer,
            renderTarget: targetColorTexture
        )
    }
}
