//
//  ResultsViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 16.12.2020.
//

import UIKit
import Vision

class ResultsViewController: UIViewController {

    
    @IBOutlet weak var myTextView: UITextView!
    @IBOutlet weak var myImageView: UIImageView!
    
    
    var image: UIImage?
    var selectedIndex: IndexPath?
    var scannedItem = ScannedItem(headline: nil, content: nil, image: nil)
    var allContent: [String] = []
     
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
     
    override func viewWillAppear(_: Bool) {
            super.viewWillAppear(true)
            setupUI()

            //call your data populating/API calls from here

    }
    
    func setupUI() {
        self.title = scannedItem.headline
        myTextView.text = scannedItem.content
        myImageView.image = scannedItem.image ?? image
    }

}

// MARK: - RecognizedTextDataSource

extension ResultsViewController: RecognizedTextDataSource {
    func addRecognizedText(recognizedText: [VNRecognizedTextObservation]) {
        // Create a full transcript to run analysis on.
        let maximumCandidates = 1
        
        for observation in recognizedText  {
            
           guard let candidate = observation.topCandidates(maximumCandidates).first else { continue }
           let text = candidate.string
           allContent.append(text)
    
           if text.count >= 3 {
               // Name is located generally on the top-left
                scannedItem.headline = text
           }
        }
        scannedItem.content = allContent.joined(separator:" ")
        

    }
    
}
