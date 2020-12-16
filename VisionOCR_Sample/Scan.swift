//
//  Scan.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 16.12.2020.
//

import UIKit.UIImage

class AllScans {
    
   static let shared = AllScans()
   var allScans = [Scan]()
    
    private init() {
        
        let image = #imageLiteral(resourceName: "sampleImage.png")
        let sample1 = Scan(headline: "Sample-1", content: "Sky is blue. Waves are coming...", image: image)
        let sample2 = Scan(headline: "Sample-2", content: "Forest is green. Birds are singing...", image: image)
        
        allScans.append(sample1)
        allScans.append(sample2)
    }
    
    
}
    
struct Scan {
    
    let headline: String
    let content: String
    let image: UIImage
    
    init(headline: String, content: String, image: UIImage) {
        self.headline = headline
        self.content = content
        self.image = image
    }
    
}
