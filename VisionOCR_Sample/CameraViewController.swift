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
    @IBOutlet weak var captureButton: UIButton!
    
    @IBOutlet weak var barcodeView: BarcodeView!
    @IBOutlet var faceView: FaceView!
    @IBOutlet var pitchView: PitchView!
    @IBOutlet weak var documentView: DocumentView!
    
    private var barcodeMode = false
    private var documentMode = false

    private var resultsViewController: ResultsViewController?
    private var orientation:CGImagePropertyOrientation = .leftMirrored
    private var documentBuffer: CVPixelBuffer?
    private var documentRectangle: VNRectangleObservation?
    private var documentImage: UIImage?
    private var isTapped = false
    
    
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
        self.barcodeView.clear()
      // When the method thinks it found a barcode, it’ll pass the barcode on to processClassification(_:)
      self.processClassification(request)
    }
    
    // MARK: Make VNRecognizeTextRequest variable

    /// - Tag: ConfigureCompletionHandler
  
    lazy var rectangleDetectionRequest = VNDetectRectanglesRequest {  request, error in
      guard error == nil else {
        self.showAlert(
          withTitle: "Rect error",
          message: error?.localizedDescription ?? "error")
        return
      }
        self.documentView.clear()
      // When the method thinks it found a rect, it’ll pass the barcode on to process(_:)
        self.processRect(request)
        }
    
    
    // MARK: Taking Photo
    @IBAction func didTakePhoto(_ sender: Any) {
        
        if documentMode {
            self.activityIndicator.startAnimating()
            self.isTapped = true
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
         // only capture normal photo in default mode or doc. do not in other modes
            stillImageOutput.capturePhoto(with: settings, delegate: self)
       
         
     }
     
    @IBAction func changeCameraButtonPressed(_ sender: Any) {
        swapCamera()
    }
    
    @IBAction func flashButtonPressed(_ sender: UIButton) {
        switch  selectedFlashMode {
        case .on:
            selectedFlashMode = .off
            sender.setImage(UIImage(named: "bolt.slash"), for: UIControl.State.normal)
        case .off:
            selectedFlashMode = .auto
            sender.setImage(UIImage(named: "bolt.badge.a"), for: UIControl.State.normal)
        default:
            selectedFlashMode = .on
            sender.setImage(UIImage(named: "bolt"), for: UIControl.State.normal)
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
    private var captureSession = AVCaptureSession()
    private var stillImageOutput: AVCapturePhotoOutput!
    private lazy var videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private var sequenceHandler = VNSequenceRequestHandler() // to detect sequence of photos
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var defaults = UserDefaults.standard
        
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
        configureCaptureSession()
        
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
      
        stillImageOutput = AVCapturePhotoOutput()
        
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
        captureSession.addOutput(stillImageOutput)
        
      let videoConnection = videoOutput.connection(with: .video)
      videoConnection?.videoOrientation = .portrait
      
      // Configure the preview layer
        setupLivePreview()
        
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
            image = UIImage(named: "bolt")!
            selectedFlashMode = .on
        case .off:
            image = UIImage(named: "bolt.slash")!
            selectedFlashMode = .off
        default:
            image = UIImage(named: "bolt.badge.a")!
            selectedFlashMode = .auto
        }
        flashButton.setImage(image, for: UIControl.State.normal)
    }
 
    //MARK: - PhotoOutput AVCapturePhotoOutput
    
    // The AVCapturePhotoOutput will deliver the captured photo to the assigned delegate which is our current ViewController by a delegate method called photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?). The photo is delivered to us as an AVCapturePhoto which is easy to transform into Data/NSData and than into UIImage.
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        let capturedImage = UIImage(data: imageData)
        if documentMode {
            delegate?.proceedFromCamera(image: documentImage)
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
    
    func drawBoundingBox(rect : CGRect) -> CGRect {
    
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.videoPreviewLayer.frame.height)
        let scale = CGAffineTransform.identity.scaledBy(x: self.videoPreviewLayer.frame.width, y: self.videoPreviewLayer.frame.height)

        let bounds = rect.applying(scale).applying(transform)
        return bounds
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
      var leftEyeBrow: [CGPoint] = []
      var rightEyeBrow: [CGPoint] = []
 
      if let points = result.landmarks?.leftEyebrow?.normalizedPoints {
        leftEyeBrow = landmark(points: points, to: result.boundingBox)!
      }
      if let points = result.landmarks?.rightEyebrow?.normalizedPoints {
        rightEyeBrow = landmark(points: points, to: result.boundingBox)!
      }
     
        // extension to create rect with min/max values
        let leftBox = CGRect(points: leftEyeBrow)!
        let rightBox = CGRect(points: rightEyeBrow)!

        let leftRatio = leftBox.height / leftBox.width
        let rightRatio = rightBox.height / rightBox.width
 
       var focusY: CGFloat = 0
       let diff = 100 * (leftRatio + rightRatio) / 2
       
 
        // FIXME - ADJUST FOR DIFFERENT PERSONS, screen distance, etc....
       
        // box will be big if face is close to camera
         // CHECK SLOPE DIRECTIONS ! NOT JUST HEIGHT/WIDTH
        print("XXXXX")
        print(leftRatio)
        print(rightRatio)
        print(diff)
        
      if (diff < CGFloat(25)) && (diff > CGFloat(17)) {
        focusY = avgY // straight look
      } else if (diff <= CGFloat(17)) {
        focusY = CGFloat(1000) // looking down
      } else if (diff >= CGFloat(25)) {
        focusY = CGFloat(-300) // looking up
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
        // call if moved phone
        defer {
          DispatchQueue.main.async { [self] in
            self.documentView.setNeedsDisplay()
          }
        }
        guard let rect = request.results?.first else { return }
        guard let result = rect as? VNRectangleObservation,
                   result.confidence > 0.98 else { return }
               
        DispatchQueue.main.async { [self] in
                let box = result.boundingBox
           documentView.boundingBox = drawBoundingBox(rect: box)
            if self.isTapped{
                self.isTapped = false
                documentImage = self.doPerspectiveCorrection(result, from:documentBuffer!)
 
            }
        }
    }
     
    // MARK: - Vision Barcode scan
    func processClassification(_ request: VNRequest) {
      // TODO: Main logic
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
              else {  return  }
 
              // Perform drawing on the main thread. 
                let box = potentialQRCode.boundingBox
                barcodeView.boundingBox = convert(rect: box)
             
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
            return 6
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
            case 5:
                cell.cameraModesLabel.text = "Smile Detection"
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
                captureButton.isHidden = false
                barcodeMode = true
                barcodeView.isHidden = false
            case 2:
                captureButton.isHidden = false
                documentView.isHidden = false
                documentMode = true
            case 3:
                // face detection
                faceView.isHidden = false
                captureButton.isHidden = true
            case 4:
                // face orientation
                pitchView.isHidden = false
                captureButton.isHidden = true
            default:
                // regular camera
                captureButton.isHidden = false
                
            }
     
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
    documentBuffer = imageBuffer
    if barcodeMode {
        let imageRequestHandler = VNImageRequestHandler(
          cvPixelBuffer: imageBuffer,
          orientation: orientation)
        // 3 Perform the detectBarcodeRequest using the handler.
        do {
          try imageRequestHandler.perform([detectBarcodeRequest])
        } catch {
          print(error)
        }
    } else if documentMode {
        let imageRequestHandler = VNImageRequestHandler(
          cvPixelBuffer: imageBuffer)
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

extension CameraViewController {
//MARK: - 1 The function doPerspectiveCorrection takes the Core Image from the buffer, converts its corners from the normalized to the image space, and applies the perspective correction filter on them to give us the image.

func doPerspectiveCorrection(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) -> UIImage {
    // FIXME: Fix coordinate system
    var ciImage: CIImage = CIImage(cvPixelBuffer: buffer)
    var output = UIImage()
    
    let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
    let topRight = observation.topRight.scaled(to: ciImage.extent.size)
    let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
    let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)

    // pass those to the filter to extract/rectify the image
    ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
        "inputTopLeft": CIVector(cgPoint: topLeft),
        "inputTopRight": CIVector(cgPoint: topRight),
        "inputBottomLeft": CIVector(cgPoint: bottomLeft),
        "inputBottomRight": CIVector(cgPoint: bottomRight),
    ])
     
            // The image doesn’t show in your album if you directly pass the CIImage into the UIImage initializer. Hence, it’s crucial that you convert the CIImage to a CGImage first, and then send it to the UIImage.
            let context = CIContext()
    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
             output = UIImage(cgImage: cgImage)
    }
        
            return output
    }

     }
  
extension CGPoint {
       func scaled(to size: CGSize) -> CGPoint {
           return CGPoint(x: self.x  * size.width,
                          y: self.y * size.height)
       }
    }
 
extension CGRect {
    init?(points: [CGPoint]) {
        let xArray = points.map(\.x)
        let yArray = points.map(\.y)
        if  let minX = xArray.min(),
            let maxX = xArray.max(),
            let minY = yArray.min(),
            let maxY = yArray.max() {

            self.init(x: minX,
                      y: minY,
                      width: maxX - minX,
                      height: maxY - minY)
        } else {
            return nil
        }
    }
}
