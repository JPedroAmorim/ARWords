//
//  ViewController.swift
//  LearningAR
//
//  Created by João Pedro de Amorim on 20/02/20.
//  Copyright © 2020 João Pedro de Amorim. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import Speech

class ViewController: UIViewController, ARSCNViewDelegate, SFSpeechRecognizerDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var arView: ARSCNView!
    @IBOutlet weak var recordButton: UIButton!
    
    // MARK: -  Properties
   private var selectedNode: SCNNode?
   private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))!
   private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
   private var recognitionTask: SFSpeechRecognitionTask?
   private let audioEngine = AVAudioEngine()
   var imageEnabled: UIImage?
   var imageDisabled: UIImage?
   var imageDots: UIImage?
    
    // MARK: - View Controller Lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ARSCNView Setup
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        arView.delegate = self
        
        // Camera physics body setup
        if let cameraNode = arView.pointOfView {
            // Geometry setup
            let cameraGeometry = SCNBox(width: 1.5, height: 2.0, length: 1.5, chamferRadius: 0.0)
            cameraNode.geometry = cameraGeometry
            
            cameraNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: cameraGeometry))
            if let cameraPhysics = cameraNode.physicsBody {
                cameraPhysics.isAffectedByGravity = false
                cameraPhysics.mass = 80
            }
        }
                
        // Speech Setup
        speechRecognizer.delegate = self
        recordButton.isEnabled = true
        
        // Icons images setup
        let bundlePathEnabled = Bundle.main.path(forResource: "icon_enabled", ofType: "png")
        let bundlePathDisabled = Bundle.main.path(forResource: "icon_disabled", ofType: "png")
        let bundlePathDots = Bundle.main.path(forResource: "three_dots", ofType: "png")
        imageEnabled = UIImage(contentsOfFile: bundlePathEnabled!)
        imageDisabled = UIImage(contentsOfFile: bundlePathDisabled!)
        imageDots = UIImage(contentsOfFile: bundlePathDots!)
        
        // Gestures Setup
        let tapPressRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapPressed))
        self.arView.addGestureRecognizer(tapPressRecognizer)
        let buttonLongPress = UILongPressGestureRecognizer(target: self, action: #selector(buttonLongPressed))
        self.recordButton.addGestureRecognizer(buttonLongPress)
    }
    
    private func startRecording() throws {
    
        // Cancel the previous task if it's running
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Audio session setup
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Recognition Request Setup
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("error") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Task setup
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                let requestResult = result.bestTranscription.formattedString
                isFinal = result.isFinal
                self.generateWord(text: requestResult)
            }
            // Task ended
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setImage(self.imageEnabled!, for: [])
            }
        }

        // Mic input setup
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setImage(self.imageEnabled!, for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    // MARK: Gestures selectors
   @objc func buttonLongPressed(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
                do {
                    try startRecording()
                    self.recordButton.setImage(self.imageDisabled!, for: [])
                } catch {
                    recordButton.setTitle("Recording Not Available", for: [])
                }
            } else if recognizer.state == .ended {
                if audioEngine.isRunning {
                    audioEngine.stop()
                    recognitionRequest?.endAudio()
                    recordButton.isEnabled = false
                    recordButton.setImage(imageDots!, for: .disabled)
               }
          }
     }
    
    @objc func tapPressed(recognizer: UITapGestureRecognizer) {
          
          guard let recognizerView = recognizer.view as? ARSCNView else { return }
          let touch = recognizer.location(in: recognizerView)
          
          // Apply torque
          if recognizer.state == .ended {
              let hitTestResult = self.arView.hitTest(touch)
              guard let hitNode = hitTestResult.first?.node else { return }
              
              self.selectedNode = hitNode
              
              // Randomizing the torque applied
              let randomArray = [Int.random(in: 0...3), Int.random(in: 0...3),
                                 Int.random(in: 0...3), Int.random(in: 0...3)]
              
              self.selectedNode?.physicsBody?.applyTorque(SCNVector4(randomArray[0], randomArray[1], randomArray[2],
                                                                     randomArray[3]), asImpulse: true)
              
              self.selectedNode = nil
          }
      }
    
        func generateWord(text: String) {
        // SCNText setup
        let textGeometry = SCNText(string: text, extrusionDepth: 2.0)
        textGeometry.firstMaterial?.isDoubleSided = true
        textGeometry.font = UIFont(name: "ComicSansMS", size: 12.0)
        textGeometry.flatness = 0.01
        // Randomizing the color a bit...
        let randomColors = [UIColor.white, UIColor.black, UIColor.orange, UIColor.blue, UIColor.yellow]
        textGeometry.firstMaterial?.diffuse.contents = randomColors[Int.random(in: 0...4)]
        
        // Necessary for the rest of the configuration
        guard let currentSession = arView.session.currentFrame else {
            return
        }
        
        // Node creation
        let myNode = SCNNode()
        myNode.geometry = textGeometry
        center(node: myNode)
        
        // Apply all the necessary transformations
        var translation = SCNMatrix4Translate(SCNMatrix4Identity, 0, 0, -1)
        translation = SCNMatrix4Rotate(translation, .pi/2, 0, 0, 1)
        var transform = float4x4(translation)
        transform = matrix_multiply(currentSession.camera.transform,transform)
        myNode.simdTransform = transform
        
        // Scaling
        myNode.scale = SCNVector3(0.01, 0.01, 0.01)
        
        // Physics body setup
        myNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: myNode))
        myNode.physicsBody?.isAffectedByGravity = false
        myNode.physicsBody?.mass = CGFloat(text.count) // Mass is calculated based upon the text length
        myNode.physicsField = .drag()  // physicsField setup
    
        arView.scene.rootNode.addChildNode(myNode)
    }
    
    //MARK: - Auxiliary methods
    func center(node: SCNNode) {
        let (min, max) = node.boundingBox

        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        node.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
    }

}
