//
//  CameraViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 17.12.2020.
//

import UIKit
import AVFoundation
import Vision

protocol CameraViewControllerDelegate: class {
    func proceedFromCamera(image: UIImage?)
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    weak var delegate: CameraViewControllerDelegate?

    private static let userDefaultsIdentifier = "flash"
    private static let collectionViewReuseIdentifier = "Cell"
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var modeCollectionView: UICollectionView!
    @IBOutlet weak var flashButton: UIButton!
    
    @IBOutlet weak var barcodeView: BarcodeView!
    @IBOutlet var faceView: FaceView!
    @IBOutlet var pitchView: PitchView!
    @IBOutlet weak var documentView: DocumentView!
    
    private var barcodeMode = false
    private var documentMode = false

    private var resultsViewController: ResultsViewController?
    private var orientation:CGImagePropertyOrientation = .leftMirrored
    
    var maskLayer = CAShapeLayer()
    // Layer into which to draw bounding box paths.
    var pathLayer: CALayer?
    private var detectionOverlay: CALayer! = nil

    // MARK: Make VNDetectBarcodesRequest variable

    lazy var detectBarcodeRequest = VNDetectBarcodesRequest { request, error in
      guard error == nil else {
        self.showAlert(
          withTitle: "Barcode error",
          message: error?.localizedDescription ?? "error")
        return
      }
      // When the method thinks it found a barcode, it’ll pass the barcode on to processClassification(_:)
      self.processClassification(request)
    }
    
    // MARK: Make VNRecognizeTextRequest variable

    /// - Tag: ConfigureCompletionHandler
    
    lazy var rectangleDetectionRequest = VNDetectRectanglesRequest { request, error in
      guard error == nil else {
        self.showAlert(
          withTitle: "Rect error",
          message: error?.localizedDescription ?? "error")
        return
      }
      // When the method thinks it found a rect, it’ll pass the barcode on to process(_:)
      self.processRect(request)
    }
     
    
    // MARK: Taking Photo
    @IBAction func didTakePhoto(_ sender: Any) {
        
        if documentMode {
            //TODO: show rectangle for the document edges. before capturing
            self.activityIndicator.startAnimating()
        }
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        switch  selectedFlashMode {
        case .on:
            settings.flashMode = .on
        case .off:
            settings.flashMode = .off
        default:
            settings.flashMode = .auto
        }
        if !barcodeMode {
            stillImageOutput.capturePhoto(with: settings, delegate: self)
        }
         
     }
     
    @IBAction func changeCameraButtonPressed(_ sender: Any) {
        swapCamera()
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
    
    func addDocumentScannerOverley() {
         
    }
    
    private enum FlashPhotoMode: Int {
        case auto = 0,on,off
    }
    
    private var selectedFlashMode = FlashPhotoMode.auto
    private var captureSession = AVCaptureSession()
    private var stillImageOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var sequenceHandler = VNSequenceRequestHandler() // to detect sequence of photos
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
        faceView.isHidden = true
        pitchView.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Setup  Photo Camera:
        configurePhotoSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
    
    /// Swap camera and reconfigures camera session with new input
    fileprivate func swapCamera() {

        // hide all
        
        // Get current input
        guard let input = captureSession.inputs[0] as? AVCaptureDeviceInput else { return }
        
        // Begin new session configuration and defer commit
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Create new capture device
        var newDevice: AVCaptureDevice?
        if input.device.position == .back {
            newDevice = captureDevice(with: .front)
            orientation = .downMirrored
        } else {
            newDevice = captureDevice(with: .back)
        }
        
        // Create new capture input
        var deviceInput: AVCaptureDeviceInput!
        do {
            deviceInput = try AVCaptureDeviceInput(device: newDevice!)
        } catch let error {
            print(error.localizedDescription)
            return
        }
        
        // Swap capture device inputs
        captureSession.removeInput(input)
        captureSession.addInput(deviceInput)

    }
 
    
    /// Create new capture device with requested position
    fileprivate func captureDevice(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {

        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [ .builtInWideAngleCamera, .builtInMicrophone, .builtInDualCamera, .builtInTelephotoCamera ], mediaType: AVMediaType.video, position: .unspecified).devices
  
            for device in devices {
                if device.position == position {
                    return device
                }
            }
        return nil
    }
    
    // put in didApper
    func configurePhotoSession() {
        // select input device
        captureSession.stopRunning()
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
            
            // remove previous session inputs.
            if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
                for input in inputs {
                    captureSession.removeInput(input)
                }
            }
            // if there are no errors, then go ahead and add input add output to the Session.
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                // remove previous session outputs.
                 let outputs = captureSession.outputs
                    for output in outputs {
                        captureSession.removeOutput(output)
                    }
                
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    
    func configureCaptureSession() {
        
        captureSession.stopRunning()
        
        let dataOutputQueue = DispatchQueue(
          label: "video data queue",
          qos: .userInitiated,
          attributes: [],
          autoreleaseFrequency: .workItem)
        
      // Define the capture device we want to use
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Unable to access back camera!")
                return
        }
      
      // Connect the camera to the capture session input
      do {
        let cameraInput = try AVCaptureDeviceInput(device: backCamera)
        // remove previous session inputs.
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession.removeInput(input)
            }
        }
        captureSession.addInput(cameraInput)
      } catch {
        fatalError(error.localizedDescription)
      }
      
      // Create the video data output
      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
      videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
      
        // remove previous session outputs.
         let outputs = captureSession.outputs
            for output in outputs {
                captureSession.removeOutput(output)
            }
     
        // Add the video output to the capture session
        captureSession.addOutput(videoOutput)
      
      let videoConnection = videoOutput.connection(with: .video)
      videoConnection?.videoOrientation = .portrait
      
      // Configure the preview layer
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = previewView.bounds
        previewView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
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
    
    func setupLivePreview() {
        // display what the camera sees on the screen in our UIView
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
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
        let capturedImage = UIImage(data: imageData)
        if documentMode {
            delegate?.proceedFromCamera(image: capturedImage)
            dismiss(animated: true, completion: nil)
        }
        captureImageView.image = capturedImage
    }
     
 
    // if you also use back camera convert
    func convert(rect: CGRect) -> CGRect {
        // 1 Calculates the location of the opposite corner to the origin of the rectangle.
        let opposite = rect.origin + rect.size.cgPoint
        let origin = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: rect.origin)
        
        // 2 Converts this opposite corner to its location in the previewLayer
        let opp = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: opposite)
        
        // 3 Calculates the size by subtracting the two points.
        let size = (opp - origin).cgSize
        return CGRect(origin: origin, size: size)
    }
    
    // helper methods for face landmarks: Define a method which converts a landmark point to something that can be drawn on the screen.
    func landmark(point: CGPoint, to rect: CGRect) -> CGPoint {
      // Calculate the absolute position of the normalized point by using a Core Graphics extension defined in CoreGraphicsExtensions.swift
      let absolute = point.absolutePoint(in: rect)
      // Convert the point to the preview layer’s coordinate system.
      let converted = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: absolute)
      
      return converted
    }

    // method takes an array of these landmark points and converts them all.
    func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
      return points?.compactMap { landmark(point: $0, to: rect) }
    }

    //MARK: - VNFaceLandmarkRegion2D methods
    
    func updateFaceView(for result: VNFaceObservation) {
      defer {
        DispatchQueue.main.async { [self] in
          self.faceView.setNeedsDisplay()
        }
      }
        
      let box = result.boundingBox
      faceView.boundingBox = convert(rect: box)

      guard let landmarks = result.landmarks else {
        return
      }
      // make up the leftEye into coordinates that work with the preview layer. If everything went well, you assign those converted points to leftEye
      if let leftEye = landmark(
        points: landmarks.leftEye?.normalizedPoints, // declared in VNFaceLandmarkRegion2D
        to: result.boundingBox) {
        faceView.leftEye = leftEye // declared in FaceView
      }
      
      //13 add other landmarks for the function
      if let rightEye = landmark(
        points: landmarks.rightEye?.normalizedPoints,
        to: result.boundingBox) {
        faceView.rightEye = rightEye
      }
          
      if let leftEyebrow = landmark(
        points: landmarks.leftEyebrow?.normalizedPoints,
        to: result.boundingBox) {
        faceView.leftEyebrow = leftEyebrow
      }
          
      if let rightEyebrow = landmark(
        points: landmarks.rightEyebrow?.normalizedPoints,
        to: result.boundingBox) {
        faceView.rightEyebrow = rightEyebrow
      }
          
      if let nose = landmark(
        points: landmarks.nose?.normalizedPoints,
        to: result.boundingBox) {
        faceView.nose = nose
      }
          
      if let outerLips = landmark(
        points: landmarks.outerLips?.normalizedPoints,
        to: result.boundingBox) {
        faceView.outerLips = outerLips
      }
          
      if let innerLips = landmark(
        points: landmarks.innerLips?.normalizedPoints,
        to: result.boundingBox) {
        faceView.innerLips = innerLips
      }
          
      if let faceContour = landmark(
            points: landmarks.faceContour?.normalizedPoints,
        to: result.boundingBox) {
        faceView.faceContour = faceContour
      }

    }

    //MARK: - LASER method for Tilt (up&down condition)
    
    func updatePitchView(for result: VNFaceObservation) {
      
      pitchView.clear()
      
      var origins: [CGPoint] = []
      // laser origin based on left and right pupil
      if let point = result.landmarks?.leftPupil?.normalizedPoints.first {
        let origin = landmark(point: point, to: result.boundingBox)
        origins.append(origin)
      }
      if let point = result.landmarks?.rightPupil?.normalizedPoints.first {
        let origin = landmark(point: point, to: result.boundingBox)
        origins.append(origin)
      }
     
      // Calculate the average y coordinate of the laser origins.
      let avgY = origins.map { $0.y }.reduce(0.0, +) / CGFloat(origins.count)
      
      // get eyebrow locations
      var eyebrowOrigins: [CGPoint] = []
      
      if let point = result.landmarks?.leftEyebrow?.normalizedPoints.first {
        let origin = landmark(point: point, to: result.boundingBox)
        eyebrowOrigins.append(origin)
      }
      if let point = result.landmarks?.rightEyebrow?.normalizedPoints.first {
        let origin = landmark(point: point, to: result.boundingBox)
        eyebrowOrigins.append(origin)
      }
      
      // Calculate the average y coordinate of the laser origins.
      let eyebrowAvgY = eyebrowOrigins.map { $0.y }.reduce(0.0, +) / CGFloat(origins.count)
      
      // compare pupils location to eye brows
      
      var focusY:  CGFloat = 0
      let diff = avgY - eyebrowAvgY
        
      // FIXME - ADJUST FOR DIFFERENT PERSONS
        
      if (diff < CGFloat(22)) && (diff > CGFloat(17)) {
        focusY = avgY // straight look
      } else if (diff >= CGFloat(22)) {
        focusY = CGFloat(1500) // looking down
      } else if (diff <= CGFloat(17)) {
        focusY = CGFloat(-500) // looking up
      }
      
      // calculate the x coordinates of the pupils
      let avgX = origins.map { $0.x }.reduce(0.0, +) / CGFloat(origins.count)
      let focusX = avgX // we're only interested in tilt dirrection here so focus point is the middle of pupils
      
      let focus = CGPoint(x: focusX, y: focusY)
      
      let originsCenter = CGPoint(x: avgX, y: avgY)
      
      let laser = Pitch(origin: originsCenter, focus: focus)
      
      pitchView.add(tilt: laser)
    
      // Tell the iPhone that the TiltView should be redrawn.
      DispatchQueue.main.async {
        self.pitchView.setNeedsDisplay()
      }
      
    }
    
    func detectedFace(request: VNRequest, error: Error?) {
      // Extract the first result from the array of face observation results.
      guard
        let results = request.results as? [VNFaceObservation],
        let result = results.first
        else {
          // Clear the FaceView if something goes wrong or no face is detected.
          faceView.clear()
          return
      }
        
        DispatchQueue.main.async() { [self] in
            
            if !faceView.isHidden {
             updateFaceView(for: result)
          } else if !pitchView.isHidden {
            updatePitchView(for: result)
          }
            
        }
    }
    
    private func showAlert(withTitle title: String, message: String) {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alertController, animated: true)
      }
    }
    
    // MARK: - Vision Rect scan
    func processRect(_ request: VNRequest) {
        documentView.clear()
        defer {
          DispatchQueue.main.async { [self] in
            self.documentView.setNeedsDisplay()
          }
        }
        
        guard let rect = request.results?.first else { return }
        DispatchQueue.main.async { [self] in
          if captureSession.isRunning {
  
              // Perform drawing on the main thread.
              DispatchQueue.main.async {
                  guard let result = rect as? VNRectangleObservation,
                        result.confidence > 0.9 else {
                          return
                  }
                   
                  let box = result.boundingBox
                documentView.boundingBox = convert(rect: box)
                    
              }
          
          }
        }
        
    }
    
    
    
    // MARK: - Vision Barcode scan
    func processClassification(_ request: VNRequest) {
      // TODO: Main logic
        barcodeView.clear()
        defer {
          DispatchQueue.main.async { [self] in
            self.barcodeView.setNeedsDisplay()
          }
        }
      // 1 get a list of potential barcodes from the request
      guard let barcodes = request.results else { return }
      DispatchQueue.main.async { [self] in
        if captureSession.isRunning {

          // 2 Loop through the potential barcodes to analyze each one individually.
          for barcode in barcodes {
            
            guard
              // TODO: Check for QR Code symbology and confidence score
              let potentialQRCode = barcode as? VNBarcodeObservation,
              potentialQRCode.confidence > 0.9
              else { return }
           
            // Perform drawing on the main thread.
            DispatchQueue.main.async {
                guard let result = barcode as? VNBarcodeObservation else {
                        return
                }
                 
                let box = result.boundingBox
                barcodeView.boundingBox = convert(rect: box)
                  
            }
            
            // 3 if one of the results happens to be a barcode, you show an alert with the barcode type and the string encoded in the barcode.
            showAlert(
              withTitle: potentialQRCode.payloadStringValue ?? "",
              // TODO: Check the confidence score
              message: String(potentialQRCode.confidence))
                 
          }
       
            
        }
      }

      
    }
 
}
    //MARK: - CollectionView DataSource & Delegate

extension CameraViewController: UICollectionViewDataSource, UICollectionViewDelegate {
     
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return 5 // will change
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraViewController.collectionViewReuseIdentifier, for: indexPath) as! CameraCollectionViewCell
        
        switch indexPath.row {
            case 1:
                cell.cameraModesLabel.text = "Barcode"
            case 2:
                cell.cameraModesLabel.text = "Document"
            case 3:
                cell.cameraModesLabel.text = "Face Detection"
            case 4:
                cell.cameraModesLabel.text = "Face Orientation"
            default:
                cell.cameraModesLabel.text = "Camera"
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
         
        if let index = self.modeCollectionView.indexPathsForSelectedItems?.first?.row {
            
            // update to change modes
            
            barcodeView.isHidden = true
            faceView.isHidden = true
            pitchView.isHidden = true
            documentView.isHidden = true
            barcodeMode = false
            documentMode = false
            
            switch index {
            case 1:
                print(index) //barcode
                barcodeMode = true
                barcodeView.isHidden = false
                configureCaptureSession()
            case 2:
                print(index) //document
                documentMode = true
                documentView.isHidden = false
                configureCaptureSession()
                addDocumentScannerOverley()
            case 3:
                // face detection
                faceView.isHidden = false
                configureCaptureSession()
            case 4:
                // face orientation
                pitchView.isHidden = false
                configureCaptureSession()
            default:
                // regular camera
                configurePhotoSession()
            }
             
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

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
   
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // Get the image buffer from the passed in sample buffer.
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
      // UPDATA for rectangles!!
    
    if barcodeMode {
        let imageRequestHandler = VNImageRequestHandler(
          cvPixelBuffer: imageBuffer,
          orientation: .right)

        // 3 Perform the detectBarcodeRequest using the handler.
        do {
          try imageRequestHandler.perform([detectBarcodeRequest])
        } catch {
          print(error)
        }
    } else if documentMode {
        let imageRequestHandler = VNImageRequestHandler(
          cvPixelBuffer: imageBuffer,
          orientation: .right)
        // 3 Perform the detectBarcodeRequest using the handler.
        do {
          try imageRequestHandler.perform([rectangleDetectionRequest])
        } catch {
          print(error)
        }
    } else {
        //to detect face landmarks update request type
        let detectFaceRequest = VNDetectFaceLandmarksRequest(completionHandler: detectedFace)

        // Use your previously defined sequence request handler to perform your face detection request on the image.
        do {
          try sequenceHandler.perform(
            [detectFaceRequest],
            on: imageBuffer,
            orientation: orientation) // tells request handler what orientation of the input image is
        } catch {
          print(error.localizedDescription)
        }
    }
    
  }
}
