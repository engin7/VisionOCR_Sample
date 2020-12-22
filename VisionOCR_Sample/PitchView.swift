// UpDown -> Neck


import UIKit

struct Pitch {
  var origin: CGPoint
  var focus: CGPoint
}

class PitchView: UIView {
  private var tilt = Pitch(origin: .zero, focus: .zero)
  
  func add(tilt: Pitch) {
    self.tilt = tilt
  }
  
  func clear() {
    tilt = Pitch(origin: .zero, focus: .zero)
    DispatchQueue.main.async {
      self.setNeedsDisplay()
    }
  }
  
  //  implement the draw method
  override func draw(_ rect: CGRect) {
    
    // Get the current graphics context.
    guard let context = UIGraphicsGetCurrentContext() else {
      return
    }
        
      // Push the current graphics state onto the stack.
      context.saveGState()
 
    context.addLines(between: [tilt.origin, tilt.focus])
       
      // Draw a thicker white line in the direction of the laser.
      context.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
      context.setLineWidth(17.5)
      context.strokePath()
          
      // Then draw a slightly thinner red line over the white line to give it a cool laser effect.
      context.addLines(between: [tilt.origin, tilt.focus])
          
      context.setStrokeColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8)
      context.setLineWidth(15.0)
      context.strokePath()
    
    // Pop the current graphics context off the stack to restore it to its original state.
    context.restoreGState()

  }
}
