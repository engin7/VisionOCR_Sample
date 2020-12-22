
import AVFoundation
import UIKit
import Vision

class FaceDetectionViewController: UIViewController {
  @IBOutlet var faceView: FaceView!
  @IBOutlet var pitchView: PitchView!
  @IBOutlet var faceLaserLabel: UILabel!

  //1 you're using Sequence.. because you’ll perform face detection requests on a series of images, instead a single static one.
  var sequenceHandler = VNSequenceRequestHandler()

  let session = AVCaptureSession()
  var previewLayer: AVCaptureVideoPreviewLayer!

  let dataOutputQueue = DispatchQueue(
    label: "video data queue",
    qos: .userInitiated,
    attributes: [],
    autoreleaseFrequency: .workItem)

  var faceViewHidden = false

  var maxX: CGFloat = 0.0
  var midY: CGFloat = 0.0
  var maxY: CGFloat = 0.0

  override func viewDidLoad() {
    super.viewDidLoad()
    configureCaptureSession()

    pitchView.isHidden = true

    maxX = view.bounds.maxX
    midY = view.bounds.midY
    maxY = view.bounds.maxY


    session.startRunning()
  }
}

// MARK: - Gesture methods

extension FaceDetectionViewController {
  @IBAction func handleTap(_ sender: UITapGestureRecognizer) {
    faceView.isHidden.toggle()
    pitchView.isHidden.toggle()

    faceViewHidden = faceView.isHidden

    if faceViewHidden {
      faceLaserLabel.text = "Lasers&Tilt"
    } else {
      faceLaserLabel.text = "Face"
    }
  }
}

// MARK: - Video Processing methods

extension FaceDetectionViewController {
  func configureCaptureSession() {
    // Define the capture device we want to use
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                               for: .video,
                                               position: .front) else {
      fatalError("No front video camera available")
    }

    // Connect the camera to the capture session input
    do {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      session.addInput(cameraInput)
    } catch {
      fatalError(error.localizedDescription)
    }

    // Create the video data output
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    // Add the video output to the capture session
    session.addOutput(videoOutput)

    let videoConnection = videoOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait

    // Configure the preview layer
    previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = view.bounds
    view.layer.insertSublayer(previewLayer, at: 0)
  }

  //4 The result’s bounding box coordinates are normalized between 0.0 and 1.0 to the input image, with the origin at the bottom left corner. That’s why you need to convert them to something useful.
  func convert(rect: CGRect) -> CGRect {
    // use helpful method from AVCaptureVideoPreviewLayer to convert origin and size
    let origin = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.origin)
    // convert the normalized size to the preview layer’s coordinate system.
    let size = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.size.cgPoint)

    return CGRect(origin: origin, size: size.cgSize)
  }

  
  //7 helper methods for face landmarks: Define a method which converts a landmark point to something that can be drawn on the screen.
  func landmark(point: CGPoint, to rect: CGRect) -> CGPoint {
    // Calculate the absolute position of the normalized point by using a Core Graphics extension defined in CoreGraphicsExtensions.swift
    let absolute = point.absolutePoint(in: rect)
    // Convert the point to the preview layer’s coordinate system.
    let converted = previewLayer.layerPointConverted(fromCaptureDevicePoint: absolute)

    return converted
  }

  //8 method takes an array of these landmark points and converts them all.
  func landmark(points: [CGPoint]?, to rect: CGRect) -> [CGPoint]? {
    return points?.compactMap { landmark(point: $0, to: rect) }
  }

  //9 make it easier to work with.
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

    if (avgY - eyebrowAvgY < CGFloat(23)) && (avgY - eyebrowAvgY > CGFloat(12)) {
      focusY = avgY // straight look
    } else if (avgY - eyebrowAvgY >= CGFloat(23)) {
      focusY = CGFloat(1500) // looking down
    } else if (avgY - eyebrowAvgY <= CGFloat(12)) {
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

  //3 define detectedFace method
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

    if faceViewHidden {
      updatePitchView(for: result)
    } else {
      updateFaceView(for: result)
    }

  }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension FaceDetectionViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  //2 fill this method
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // Get the image buffer from the passed in sample buffer.
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }

    // Create a face detection request to detect face bounding boxes and pass the results to a completion handler.
//    let detectFaceRequest = VNDetectFaceRectanglesRequest(completionHandler: detectedFace) //call func detectedFace after completing

    //6 to detect face landmarks update request type
    let detectFaceRequest = VNDetectFaceLandmarksRequest(completionHandler: detectedFace)

    // Use your previously defined sequence request handler to perform your face detection request on the image.
    do {
      try sequenceHandler.perform(
        [detectFaceRequest],
        on: imageBuffer,
        orientation: .leftMirrored) // tells request handler what orientation of the input image is
    } catch {
      print(error.localizedDescription)
    }

  }
}
