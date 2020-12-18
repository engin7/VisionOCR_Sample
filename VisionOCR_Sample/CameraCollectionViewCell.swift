//
//  CameraCollectionViewCell.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 17.12.2020.
//

import UIKit

class CameraCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cameraModesLabel: UILabel!
    
    override func awakeFromNib() {
            super.awakeFromNib()
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            cameraModesLabel.text = ""
            
        }
    
    
    
}
