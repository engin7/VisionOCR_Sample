//
//  CameraViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 17.12.2020.
//

import UIKit
import AVFoundation


class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    private static let userDefaultsIdentifier = "flash"
    private static let collectionViewReuseIdentifier = "Cell"

    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var modeCollectionView: UICollectionView!
    @IBOutlet weak var flashButton: UIButton!
    
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
    
    
    
}
