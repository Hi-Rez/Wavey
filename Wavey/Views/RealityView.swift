//
//  RealityView.swift
//  Really
//
//  Created by Reza Ali on 7/19/22.
//

import ARKit
import Combine
import Foundation
import MetalPerformanceShaders
import RealityKit
import Satin
import SwiftUI

class RealityView: ARView {
    /// The main view for the app.
    var arView: ARView { return self }
    
    /// A view that guides the user through capturing the scene.
    var coachingView: ARCoachingOverlayView?
    
    // MARK: - Paths
    
    var assetsURL: URL { Bundle.main.resourceURL!.appendingPathComponent("Assets") }
    var modelsURL: URL { assetsURL.appendingPathComponent("Models") }
    var pipelinesURL: URL { assetsURL.appendingPathComponent("Pipelines") }
    
    // MARK: - Files to load
    
    var cancellables = [AnyCancellable]()
    lazy var modelURL = modelsURL.appendingPathComponent("tv_retro.usdz")
    var modelEntity: ModelEntity?
    var modelAnchor: AnchorEntity?
    
    // MARK: - Satin

    var satinRenderer: Renderer!
    
    var satinScene = Object("Satin Scene")
    var satinWaveyMesh: Mesh!
    var containerAnchor: ARAnchor?
    var satinMeshContainer = Object("Mesh Container")
//    var satinAxis = Object("Axis")
    var satinCamera = PerspectiveCamera(position: [0, 0, 5], near: 0.01, far: 100.0)
    
    var orientation: UIInterfaceOrientation?
    var _updateContext: Bool = true
    
    // MARK: - Camera Textures
    
    var cameraTexture: MTLTexture?
        
    // Background Textures
    var capturedImageTextureY: CVMetalTexture?
    var capturedImageTextureCbCr: CVMetalTexture?

    // Captured image texture cache
    var capturedImageTextureCache: CVMetalTextureCache!

    // MARK: - Background Renderer

    var viewportSize = CGSize(width: 0, height: 0)
    var cameraGeometryNeedsUpdate = true

    lazy var cameraMesh: Mesh = {
        let mesh = Mesh(geometry: QuadGeometry(), material: CameraMaterial(pipelinesURL: pipelinesURL))
        mesh.preDraw = { [weak self] renderEncoder in
            guard let self = self, let textureY = self.capturedImageTextureY, let textureCbCr = self.capturedImageTextureCbCr else { return }
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: FragmentTextureIndex.Custom0.rawValue)
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: FragmentTextureIndex.Custom1.rawValue)
        }
        mesh.label = "Video Mesh"
        return mesh
    }()
    
    var cameraRenderer: Satin.Renderer!
    
    // MARK: - Occulsion / Depth
    
    var capturedDepthTexture: CVMetalTexture?
    var capturedDepthTextureCache: CVMetalTextureCache!
    
    // MARK: - Initializers
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedView))
        arView.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func tappedView(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        
        let location = sender.location(in: arView)
        let results = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any)
        
        guard let result = results.first else { return }
                
        if let containerAnchor = self.containerAnchor {
            session.remove(anchor: containerAnchor)
        }
        
        satinMeshContainer.localMatrix = result.worldTransform
        let containerAnchor = ARAnchor(transform: result.worldTransform)
        self.session.add(anchor: containerAnchor)
        self.containerAnchor = containerAnchor
        satinMeshContainer.visible = true
    }
    
    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup and Configuration
    
    /// RealityKit calls this function before it renders the first frame. This method handles any
    /// setup work that has to be done after the ARView finishes its setup.
    func postProcessSetupCallback(device: MTLDevice) {
        setUpCoachingOverlay()
        setupOrientationAndObserver()
        setupSatin(device: device)
        configureWorldTracking()
    }
    
    func setupOrientationAndObserver() {
        orientation = getOrientation()
        NotificationCenter.default.addObserver(self, selector: #selector(RealityView.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func rotated() {
        orientation = getOrientation()
        cameraGeometryNeedsUpdate = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}
