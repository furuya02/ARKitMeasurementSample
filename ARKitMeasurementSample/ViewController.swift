//
//  ViewController.swift
//  ARKitMeasurementSample
//
//  Created by SIN on 2017/09/01.
//  Copyright © 2017年 Classmethod.Inc. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

enum MarkerMode {
    case white
    case black
    case none
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    var recordingButton: RecordingButton!
    var markerMode = MarkerMode.white
    var startPosition: SCNVector3!
    var isMeasuring = false
    var timer: Timer!
    var cylinderNode: SCNNode?
    
    @IBOutlet weak var imageMaker: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        // 録画ボタン
        //self.recordingButton = RecordingButton(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer.fire()
    }
    
    @IBAction func tapToggleMaker(_ sender: Any) {
        
        switch markerMode {
        case .white:
            markerMode = .black
            imageMaker.image = UIImage(named: "Landmark_Black")
        case .black:
            markerMode = .none
            imageMaker.image = UIImage(named: "")
        case .none:
            markerMode = .white
            imageMaker.image = UIImage(named: "Landmark_White")
        }
    }
    
    // 球体のノードの作成
    func createSphereNode(position: SCNVector3, color: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 0.005)
        let material = SCNMaterial()
        material.diffuse.contents = color
        sphere.materials = [material]
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = position
        return sphereNode
    }
    
    // 線のノードの作成
    func createLineNode(startPosition: SCNVector3, endPosition: SCNVector3, color: UIColor) -> SCNNode {
        let indices: [Int32] = [0, 1]
        let source = SCNGeometrySource(vertices: [startPosition, endPosition])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let line = SCNGeometry(sources: [source], elements: [element])
        line.firstMaterial?.lightingModel = SCNMaterial.LightingModel.blinn
        let lineNode = SCNNode(geometry: line)
        lineNode.geometry?.firstMaterial?.diffuse.contents = color
        return lineNode
    }
    
    // 円柱のノードの作成
    //https://stackoverflow.com/questions/30827401/cylinder-orientation-between-two-points-on-a-sphere-scenekit-quaternions-ios
    func createCylinderNode(startPosition: SCNVector3, endPosition: SCNVector3, radius: CGFloat , color: UIColor, transparency: CGFloat) -> SCNNode {
        
        let height = CGFloat(GLKVector3Distance(SCNVector3ToGLKVector3(startPosition), SCNVector3ToGLKVector3(endPosition)))
        
        let cylinderNode = SCNNode()
        cylinderNode.eulerAngles.x = Float(Double.pi / 2)
        
        let cylinderGeometry = SCNCylinder(radius: radius, height: height)
        cylinderGeometry.firstMaterial?.diffuse.contents = color
        let cylinder = SCNNode(geometry: cylinderGeometry)
        
        cylinder.position.y = Float(-height/2)
        cylinderNode.addChildNode(cylinder)
        
        let node = SCNNode()
        let targetNode = SCNNode()
        
        if (startPosition.z < 0.0 && endPosition.z > 0.0) {
            node.position = endPosition
            targetNode.position = startPosition
        } else {
            node.position = startPosition
            targetNode.position = endPosition
        }
        node.addChildNode(cylinderNode)
        node.constraints = [ SCNLookAtConstraint(target: targetNode) ]
        return node
    }
    
    // 計測開始
    @IBAction func beginMeasure(_ sender: Any) {
        if let position = getCenter() {
            for node in sceneView.scene.rootNode.childNodes {
                node.removeFromParentNode()
            }
            startPosition = position
            isMeasuring = true
            
            let sphereNode = createSphereNode(position: startPosition, color: UIColor.red)
            sceneView.scene.rootNode.addChildNode(sphereNode)
        }
    }
    // 計測終了
    func endMeasure() {
        if !isMeasuring {
            return
        }
        isMeasuring = false
        
        if let endPosition = getCenter() {
            
            let sphereNode = createSphereNode(position: endPosition, color: UIColor.red)
            sceneView.scene.rootNode.addChildNode(sphereNode)
            
            let centerPosition = Center(startPosition: startPosition, endPosition: endPosition)
            let centerSphereNode = createSphereNode(position: centerPosition, color: UIColor.orange)
            sceneView.scene.rootNode.addChildNode(centerSphereNode)
            
            let lineNode = createLineNode(startPosition: startPosition, endPosition: endPosition, color: UIColor.white)
            sceneView.scene.rootNode.addChildNode(lineNode)
            
            refreshCylinderNode(endPosition: endPosition)
        }
    }
    
    @IBAction func touchUpInside(_ sender: Any) {
        endMeasure()
    }
    
    @IBAction func touchUpOutside(_ sender: Any) {
        endMeasure()
    }
    
    // 画面の中央を取得する
    func getCenter() -> SCNVector3? {
        let touchLocation = sceneView.center
        let hitResults = sceneView.hitTest(touchLocation, types: [.featurePoint])
        if !hitResults.isEmpty {
            if let hitTResult = hitResults.first {
                return SCNVector3(hitTResult.worldTransform.columns.3.x, hitTResult.worldTransform.columns.3.y, hitTResult.worldTransform.columns.3.z)
            }
        }
        return nil
    }
    
    // 2点間の中心座標を取得する
    func Center(startPosition: SCNVector3, endPosition: SCNVector3) -> SCNVector3 {
        let x = endPosition.x - startPosition.x
        let y = endPosition.y - startPosition.y
        let z = endPosition.z - startPosition.z
        return SCNVector3Make(endPosition.x - x/2, endPosition.y - y/2, endPosition.z - z/2)
    }
    
    // 計測中に円柱の描画を更新する
    @objc func update(tm: Timer) {
        if isMeasuring {
            if let endPosition = getCenter() {
                let position = SCNVector3Make(endPosition.x - startPosition.x, endPosition.y - startPosition.y, endPosition.z - startPosition.z)
                let distance = sqrt(position.x*position.x + position.y*position.y + position.z*position.z)
                label.text = String.init(format: "%.2fm", arguments: [distance])
                
                refreshCylinderNode(endPosition: endPosition)
            }
        }
    }
    
    // 円柱の更新
    func refreshCylinderNode(endPosition: SCNVector3) {
        if let node = cylinderNode {
            node.removeFromParentNode()
        }
        cylinderNode = createCylinderNode(startPosition: startPosition, endPosition: endPosition, radius: 0.001, color: UIColor.yellow, transparency: 0.5)
        sceneView.scene.rootNode.addChildNode(cylinderNode!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        timer.invalidate()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - ARSCNViewDelegate
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

