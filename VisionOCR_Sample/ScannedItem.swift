//
//  Scan.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 16.12.2020.
//

import UIKit.UIImage

class AllScans {
    
   static let shared = AllScans()
   var allScans = [ScannedItem]()
    
    private init() {
        
        let image = UIImage(systemName: "doc.text.viewfinder")
        let sample1 = ScannedItem(headline: "Sample-1", content: "Sky is blue. Waves are coming...", image: image)
        let sample2 = ScannedItem(headline: "Sample-2", content: "Forest is green. Birds are singing...", image: image)
        
        allScans.append(sample1)
        allScans.append(sample2)
    }
    
    
}
    
struct ScannedItem {
    
    var headline: String
    var content: String
    var image: UIImage?
    
    init(headline: String?, content: String?, image: UIImage?) {
        self.headline = headline ?? "Scanned Item"
        self.content = content ?? "Could not scan this document"
        self.image = image ?? nil
    }
    
}
