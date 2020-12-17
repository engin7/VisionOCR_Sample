//
//  CameraViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 17.12.2020.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var modeCollectionView: UICollectionView!
    @IBOutlet weak var cameraModeLabel: UILabel!
    
    @IBAction func didTakePhoto(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
     
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
     
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
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
        
        videoPreviewLayer.videoGravity = .resizeAspect
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
    
    
    // The AVCapturePhotoOutput will deliver the captured photo to the assigned delegate which is our current ViewController by a delegate method called photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?). The photo is delivered to us as an AVCapturePhoto which is easy to transform into Data/NSData and than into UIImage.
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        let image = UIImage(data: imageData)
        captureImageView.image = image
    }
    
    
    

}
