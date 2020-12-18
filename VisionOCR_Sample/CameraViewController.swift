//
//  CameraViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 17.12.2020.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    private static let userDefaultsIdentifier = "flash"
    private static let collectionViewReuseIdentifier = "Cell"

    
    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var modeCollectionView: UICollectionView!
    @IBOutlet weak var flashButton: UIButton!
    private var resultsViewController: ResultsViewController?
    
    var maskLayer = CAShapeLayer()
    // Device orientation. Updated whenever the orientation changes
    var currentOrientation = UIDeviceOrientation.portrait
    
    
    
    @IBAction func didTakePhoto(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        switch  selectedFlashMode {
        case .on:
            settings.flashMode = .on
        case .off:
            settings.flashMode = .off
        default:
            settings.flashMode = .auto
        }
        stillImageOutput.capturePhoto(with: settings, delegate: self)
     }
     
    @IBAction func flashButtonPressed(_ sender: UIButton) {
        switch  selectedFlashMode {
        case .on:
            selectedFlashMode = .off
            sender.setImage(UIImage(systemName: "bolt.slash")!, for: UIControl.State.normal)
        case .off:
            selectedFlashMode = .auto
            sender.setImage(UIImage(systemName: "bolt.badge.a")!, for: UIControl.State.normal)
        default:
            selectedFlashMode = .on
            sender.setImage(UIImage(systemName: "bolt")!, for: UIControl.State.normal)
        }
       
    }
    
    @IBAction func closeButtonPressed(_ sender: Any) {
        defaults.set(selectedFlashMode.rawValue, forKey: CameraViewController.userDefaultsIdentifier)
        dismiss(animated: true, completion: nil)
    }
     

    private enum FlashPhotoMode: Int {
        case auto = 0,on,off
    }
 
    private var selectedFlashMode = FlashPhotoMode.auto
    private var captureSession: AVCaptureSession!
    private var stillImageOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var defaults = UserDefaults.standard
        
    // MARK: - Coordinate transforms
    var bufferAspectRatio: Double!
    // Transform from UI orientation to buffer orientation.
    var uiRotationTransform = CGAffineTransform.identity
    // Transform bottom-left coordinates to top-left.
    var bottomToTopTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    // Transform coordinates in ROI to global coordinates (still normalized).
    var roiToGlobalTransform = CGAffineTransform.identity
    
    // Vision -> AVF coordinate transform.
    var visionToAVFTransform = CGAffineTransform.identity
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupFlash()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Setup Camera:
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .low
        // select input device
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Unable to access back camera!")
                return
        }
        //The AVCaptureDeviceInput will serve as the "middle man" to attach the input device, backCamera to the session.
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            // AVCapturePhotoOutput to help us attach the output to the session.
            stillImageOutput = AVCapturePhotoOutput()
            // if there are no errors, then go ahead and add input add output to the Session.
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    func setupLivePreview() {
        // display what the camera sees on the screen in our UIView
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // captureSession can block the UI
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                // setting UI elements should be on the main thread
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
        
    }
   
    func setupFlash() {
        var image: UIImage
        let flashHashValue = defaults.integer(forKey: CameraViewController.userDefaultsIdentifier)
        let chosenFlash = FlashPhotoMode(rawValue: flashHashValue) ?? FlashPhotoMode.auto
        
        switch  chosenFlash {
        case .on:
            image = UIImage(systemName: "bolt")!
            selectedFlashMode = .on
        case .off:
            image = UIImage(systemName: "bolt.slash")!
            selectedFlashMode = .off
        default:
            image = UIImage(systemName: "bolt.badge.a")!
            selectedFlashMode = .auto
        }
        flashButton.setImage(image, for: UIControl.State.normal)
    }

    
    // The AVCapturePhotoOutput will deliver the captured photo to the assigned delegate which is our current ViewController by a delegate method called photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?). The photo is delivered to us as an AVCapturePhoto which is easy to transform into Data/NSData and than into UIImage.
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        let image = UIImage(data: imageData)
        captureImageView.image = image
    }
     
    // MARK: - Bounding box drawing
    
    // Draw a box on screen. Must be called from main queue.
    var boxLayer = [CAShapeLayer]()
    func draw(rect: CGRect, color: CGColor) {
        let layer = CAShapeLayer()
        layer.opacity = 0.5
        layer.borderColor = color
        layer.borderWidth = 1
        layer.frame = rect
        boxLayer.append(layer)
        videoPreviewLayer.insertSublayer(layer, at: 1)
    }
    
    // Remove all drawn boxes. Must be called on main queue.
    func removeBoxes() {
        for layer in boxLayer {
            layer.removeFromSuperlayer()
        }
        boxLayer.removeAll()
    }
    
    typealias ColoredBoxGroup = (color: CGColor, boxes: [CGRect])
    
    // Draws groups of colored boxes.
    func show(boxGroups: [ColoredBoxGroup]) {
        DispatchQueue.main.async {
            let layer = self.videoPreviewLayer
            self.removeBoxes()
            for boxGroup in boxGroups {
                let color = boxGroup.color
                for box in boxGroup.boxes {
                    if let rect = layer?.layerRectConverted(fromMetadataOutputRect: box.applying(self.visionToAVFTransform)) {
                        self.draw(rect: rect, color: color)
                    }
                }
            }
        }
    }
    
}


extension CameraViewController: UICollectionViewDataSource, UICollectionViewDelegate {
     
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
            return 4 // will change
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraViewController.collectionViewReuseIdentifier, for: indexPath) as! CameraCollectionViewCell
        
        cell.cameraModesLabel.text = "Scan Mode"
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
         
        if let index = self.modeCollectionView.indexPathsForSelectedItems?.first {
            
            print(index)
            // update to change modes
            
            // add overlay run delegate method
            // this one adds overlay afterwords
            // https://developer.apple.com/documentation/vision/detecting_objects_in_still_images
            // Running realtime numbers (adding realtime overlay)
            // DetectingObjectsInStillImages (sample code for face, rect, barcode read)
            
            // need to add custom control here instead of CollectionView. Use collectionView for photo gallery.
            //  horizontal scroll view containing multiple UILabel objects, each of which has an attached UITapGestureRecognizer.
           //  https://www.raywenderlich.com/5294-how-to-make-a-custom-control-tutorial-a-reusable-knob
            // check also Cocoa Controls for framework
            
        }
    }
}

// MARK: - Utility extensions

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}
