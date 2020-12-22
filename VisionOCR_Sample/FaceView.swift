

import UIKit
import Vision

class FaceView: UIView {
  var leftEye: [CGPoint] = []
  var rightEye: [CGPoint] = []
  var leftEyebrow: [CGPoint] = []
  var rightEyebrow: [CGPoint] = []
  var nose: [CGPoint] = []
  var outerLips: [CGPoint] = []
  var innerLips: [CGPoint] = []
  var faceContour: [CGPoint] = []

  var boundingBox = CGRect.zero
  
  func clear() {
    leftEye = []
    rightEye = []
    leftEyebrow = []
    rightEyebrow = []
    nose = []
    outerLips = []
    innerLips = []
    faceContour = []
    
    boundingBox = .zero
    
    DispatchQueue.main.async {
      self.setNeedsDisplay()
    }
  }
  
  //5 draw red square around your face
  override func draw(_ rect: CGRect) {
    // get the current graphics context
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }
    // push the current graphics state onto the stack
    context.saveGState()
    // Restore the graphics state when this method exits.
    defer {
      context.restoreGState()
    }
    // Add a path describing the bounding box to the context.
    context.addRect(boundingBox)

    // use red color
    UIColor.red.setStroke()

    // draw path .addRect
    context.strokePath()
    
    //11 add drawing for eye
    UIColor.white.setStroke()
        
    if !leftEye.isEmpty {
      // Add lines between the points that define the leftEye, if there are any points.
      context.addLines(between: leftEye)
      context.closePath()
      // Stroke the path, to make it visible.
      context.strokePath()
    }
    // With Vision, you should expect to see the outline drawn not on your left eye, but on your eye which is on the left side of the image.
    
    //12 add other face features:
    
    if !rightEye.isEmpty {
      context.addLines(between: rightEye)
      context.closePath()
      context.strokePath()
    }
        
    if !leftEyebrow.isEmpty {
      context.addLines(between: leftEyebrow)
      context.strokePath()
    }
        
    if !rightEyebrow.isEmpty {
      context.addLines(between: rightEyebrow)
      context.strokePath()
    }
        
    if !nose.isEmpty {
      context.addLines(between: nose)
      context.strokePath()
    }
        
    if !outerLips.isEmpty {
      context.addLines(between: outerLips)
      context.closePath()
      context.strokePath()
    }
        
    if !innerLips.isEmpty {
      context.addLines(between: innerLips)
      context.closePath()
      context.strokePath()
    }
        
    if !faceContour.isEmpty {
      context.addLines(between: faceContour)
      context.strokePath()
    }

    
    
  }
}
