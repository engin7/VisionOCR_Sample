//
//  BarcodeView.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 25.12.2020.
//

import UIKit
 

class BarcodeView: UIView {
 
    var boundingBox = CGRect.zero

    func clear() {
        boundingBox = .zero
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
          
        defer {
          context.restoreGState()
        }
        
        // Push the current graphics state onto the stack.
        context.saveGState()
   
        // Add a path describing the bounding box to the context.
        context.addRect(boundingBox)

        // use red color
        UIColor.red.setStroke()

        // draw path .addRect
        context.strokePath()
         
     

    }
  }
    
    
  
