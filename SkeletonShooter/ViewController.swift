//
//  ViewController.swift
//  SkeletonShooter
//
//  Created by Ivan on 2019-04-02.
//  Copyright © 2019 CentennialCollege. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    /////////////////////
    // MARK: - VARIABLES
    ////////////////////
    
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var target: UIImageView!
    
    @IBOutlet weak var timerLabel: UILabel!
    
    @IBOutlet weak var scoreLabel: UILabel!
    
    var score = 0
    
    ///////////////////
    // MARK: - BUTTONS
    //////////////////
    
    @IBOutlet weak var onBulletButton: UIButton!
    @IBAction func onBulletButton(_ sender: Any) {
        fireMissile(type: "bullet")
    }
    
    ////////////////////////
    // MARK: - CREATE NODES
    ///////////////////////
    
    var center: CGPoint!
    let trackerNode = SCNScene(named: "art.scnassets/tracker.scn")!.rootNode
    var gameNode = SCNScene(named: "art.scnassets/scene.scn")!.rootNode
    var positions = [SCNVector3]()
    
    //////////////////////
    // MARK: - GAME STATE
    /////////////////////
    
    var isGameOn = false
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if !isGameOn {
            let hitTest = sceneView.hitTest(center, types: .featurePoint)
            let result = hitTest.last
            guard let transform = result?.worldTransform else { return }
            let thirdColumn = transform.columns.3
            let position = SCNVector3Make(thirdColumn.x, thirdColumn.y, thirdColumn.z)
            positions.append(position)
            let lastTenPositions = positions.suffix(10)
            trackerNode.position = getAveragePosition(from: lastTenPositions)
        }
    }
    
    func getAveragePosition(from positions: ArraySlice<SCNVector3>) -> SCNVector3 {
        var averageX : Float = 0
        var averageY : Float = 0
        var averageZ : Float = 0
        
        for position in positions {
            averageX += position.x
            averageY += position.y
            averageZ += position.z
        }
        
        let count = Float(positions.count)
        return SCNVector3Make(averageX / count, averageY / count, averageZ / count)
    }
    
    // Create game loop
    func initGame() {
        target.isHidden = false
        timerLabel.isHidden = false
        onBulletButton.isHidden = false
        scoreLabel.isHidden = false
        
        addSkulls()
        
        playBackgroundMusic()
        
        runTimer()
        
        isGameOn = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOn {
            return
        } else {
            // Place the gameNode
            guard let angle = sceneView.session.currentFrame?.camera.eulerAngles.y else { return }
            gameNode.position = trackerNode.position
            gameNode.eulerAngles.y = angle
            trackerNode.removeFromParentNode()
            sceneView.scene.rootNode.addChildNode(gameNode)
            initGame()
        }
    }
    
    /////////////////
    // MARK: - MATHS
    ////////////////
    
    // (direction, position)
    func getUserVector() -> (SCNVector3, SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            // 4x4 transform matrix describing camera in world space
            let mat = SCNMatrix4(frame.camera.transform)
            // Orientation of camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
            // Location of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43)
            
            return (dir, pos)
        }
        
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    //////////////////////////
    // MARK: - VIEW FUNCTIONS
    /////////////////////////
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        
        sceneView.showsStatistics = false
        
        self.sceneView.autoenablesDefaultLighting = true
        
        sceneView.scene.physicsWorld.contactDelegate = self
        
        timerLabel.layer.masksToBounds = true
        timerLabel.layer.cornerRadius = 30
        scoreLabel.layer.masksToBounds = true
        scoreLabel.layer.cornerRadius = 30
        
        center = view.center
        sceneView.scene.rootNode.addChildNode(trackerNode)
        
        target.isHidden = true
        timerLabel.isHidden = true
        onBulletButton.isHidden = true
        scoreLabel.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.environmentTexturing = .automatic
        
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    //////////////////
    // MARK: - TIMERS
    /////////////////
    
    var skullTimer1 = Timer()
    var skullTimer2 = Timer()
    
    func addSkulls() {
        skullTimer1 = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.addSkull1TargetNodes)), userInfo: nil, repeats: true)
        skullTimer2 = Timer.scheduledTimer(timeInterval: 3, target: self, selector: (#selector(self.addSkull2TargetNodes)), userInfo: nil, repeats: true)
    }
    
    var seconds = 30
    
    var timer = Timer()
    
    var isTimerRunning = false
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.updateTimer)), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        if seconds == 0 {
            timer.invalidate()
            gameOver()
        } else {
            seconds -= 1
            timerLabel.text = "\(seconds)"
        }
    }
    
    func resetTimer() {
        timer.invalidate()
        seconds = 30
        timerLabel.text = "\(seconds)"
    }
    
    /////////////////////
    // MARK: - GAME OVER
    ////////////////////
    
    func gameOver() {
        let defaults = UserDefaults.standard
        defaults.set(score, forKey: "score")
        
        self.dismiss(animated: true, completion: nil)
        
        skullTimer1.invalidate()
        skullTimer2.invalidate()
    }
    
    //////////////////////////////
    // MARK: - MISSILES & TARGETS
    /////////////////////////////
    
    func fireMissile(type : String){
        var node = SCNNode()
        
        node = createMissile(type: type)
        
        let (direction, position) = self.getUserVector()
        node.position = position
        
        var nodeDirection = SCNVector3()
        
        switch type {
        case "bullet":
            nodeDirection  = SCNVector3(direction.x * 4, direction.y * 4, direction.z * 4)
            node.physicsBody?.applyForce(nodeDirection, at: SCNVector3(0.1, 0, 0), asImpulse: true)
            playSound(sound: "gunSound", format: "wav")
            
            // Remove ball after 3 seconds
            let disapear = SCNAction.fadeOut(duration: 0.3)
            node.runAction(.sequence([.wait(duration: 6), disapear]))
        default:
            nodeDirection = direction
        }
        
        // Move node
        node.physicsBody?.applyForce(nodeDirection, asImpulse: true)
        
        // Add node to scene
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    // Create nodes
    func createMissile(type: String) -> SCNNode {
        var node = SCNNode()
        
        switch type {
        case "bullet":
            let scene = SCNScene(named: "art.scnassets/bullet.scn")
            node = (scene?.rootNode.childNode(withName: "bullet", recursively: true)!)!
            node.scale = SCNVector3(0.2, 0.2, 0.2)
            node.name = "bullet"
        default:
            node = SCNNode()
        }
        
        // The physics body governs how the object interacts with other objects and its environment
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        // These bitmasks used to define "collisions" with other objects
        node.physicsBody?.categoryBitMask = CollisionCategory.missileCategory.rawValue
        node.physicsBody?.collisionBitMask = CollisionCategory.targetCategory.rawValue
        return node
    }
    
    // Add skull1 target nodes
    @objc func addSkull1TargetNodes() {
        var node = SCNNode()
        
        let scene = SCNScene(named: "art.scnassets/plane.scn")
        node = (scene?.rootNode.childNode(withName: "plane", recursively: true)!)!
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        node.name = "plane"
        
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        node.position = SCNVector3(randomFloat(min: -2, max: 2), randomFloat(min: -2, max: 2), -8)
        
        let particleSystem = SCNParticleSystem(named: "smoke.scnp", inDirectory: nil)
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem!)
        
        node.addChildNode(particleNode)
        particleNode.position = SCNVector3Make(0, 0, 0)
        
        node.physicsBody?.categoryBitMask = CollisionCategory.targetCategory.rawValue
        node.physicsBody?.contactTestBitMask = CollisionCategory.missileCategory.rawValue
        
        let disapear = SCNAction.fadeOut(duration: 0.3)
        node.runAction(.sequence([.wait(duration: 3), disapear]))
        
        sceneView.scene.rootNode.addChildNode(node)
        
        let force = simd_make_float4(0, 0, randomFloat(min: 5, max: 10), 0)
        let rotatedForce = simd_mul(node.presentation.simdTransform, force)
        let vectorForce = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)
        node.physicsBody?.applyForce(vectorForce, asImpulse: true)
    }
    
    @objc func addSkull2TargetNodes() {
        var node = SCNNode()
        
        let scene = SCNScene(named: "art.scnassets/unii1.scn")
        node = (scene?.rootNode.childNode(withName: "devil", recursively: true)!)!
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        node.name = "devil"
        
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        node.position = SCNVector3(randomFloat(min: -2, max: 2), randomFloat(min: -2, max: 2), -8)
        
        let particleSystem = SCNParticleSystem(named: "smoke.scnp", inDirectory: nil)
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem!)
        
        node.addChildNode(particleNode)
        particleNode.position = SCNVector3Make(0, 0, 0)
        
        node.physicsBody?.categoryBitMask = CollisionCategory.targetCategory.rawValue
        node.physicsBody?.contactTestBitMask = CollisionCategory.missileCategory.rawValue
        
        let disapear = SCNAction.fadeOut(duration: 0.3)
        node.runAction(.sequence([.wait(duration: 2), disapear]))
        
        sceneView.scene.rootNode.addChildNode(node)
        
        let force = simd_make_float4(0, 0, randomFloat(min: 20, max: 60), 0)
        let rotatedForce = simd_mul(node.presentation.simdTransform, force)
        let vectorForce = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)
        node.physicsBody?.applyForce(vectorForce, asImpulse: true)
    }
    
    // Create random float between specified ranges
    func randomFloat(min: Float, max: Float) -> Float {
        return (Float(arc4random()) / 0xFFFFFFFF) * (max - min) + min
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    /////////////////////////////
    // MARK: - ARSCNVIEWDELEGATE
    ////////////////////////////
    
    func session(_ session: ARSession, didFailWithError error: Error) {
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
    }
    
    ////////////////////////////
    // MARK: - delegate
    ///////////////////////////
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print("** Collision!! " + contact.nodeA.name! + " hit " + contact.nodeB.name!)
        
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue {
            if(contact.nodeA.name! == "skull2" || contact.nodeB.name! == "skull2") {
                score += 5
            } else {
                score += 1
            }
            
            DispatchQueue.main.async {
                contact.nodeA.removeFromParentNode()
                contact.nodeB.removeFromParentNode()
                self.scoreLabel.text = String(self.score)
            }
            
            playSound(sound: "kaboom", format: "mp3")
            let kaboom = SCNParticleSystem(named: "fire", inDirectory: nil)
            contact.nodeB.addParticleSystem(kaboom!)
        }
    }
    
    //////////////////
    // MARK: - SOUNDS
    /////////////////
    
    var player: AVAudioPlayer?
    
    func playSound(sound : String, format: String) {
        guard let url = Bundle.main.url(forResource: sound, withExtension: format) else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            guard let player = player else { return }
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func playBackgroundMusic(){
        let audioNode = SCNNode()
        let audioSource = SCNAudioSource(fileNamed: "wow.aiff")!
        let audioPlayer = SCNAudioPlayer(source: audioSource)
        
        audioNode.addAudioPlayer(audioPlayer)
        
        let play = SCNAction.playAudio(audioSource, waitForCompletion: true)
        audioNode.runAction(play)
        sceneView.scene.rootNode.addChildNode(audioNode)
    }
}

struct CollisionCategory: OptionSet {
    let rawValue: Int
    
    static let missileCategory  = CollisionCategory(rawValue: 1 << 0)
    static let targetCategory = CollisionCategory(rawValue: 1 << 1)
    static let otherCategory = CollisionCategory(rawValue: 1 << 2)
}

fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}

