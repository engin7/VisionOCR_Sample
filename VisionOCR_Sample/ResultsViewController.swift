//
//  ResultsViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 16.12.2020.
//

import UIKit
import Vision
import PDFKit

class ResultsViewController: UIViewController {

    @IBOutlet weak var myTextView: UITextView!
    @IBOutlet weak var myImageView: UIImageView!
    @IBOutlet weak var hudImageView: UIImageView!
     
    @IBAction func saveToDiskAction(_ sender: Any) {
        save()
    }
    
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
    }
    
    func setupUI() {
        hudImageView.isHidden = true
        self.title = scannedItem.headline
        myTextView.text = scannedItem.content
        myImageView.image = scannedItem.image ?? image
    }

    func save() {
        dataBase.append(scannedItem)
        myTextView.alpha = 0.4
        myImageView.alpha = 0.4
        hudImageView.isHidden = false
        hudImageView.alpha = 1.0
        let n: Int! = self.navigationController?.viewControllers.count
        let listVC = self.navigationController?.viewControllers[n-2] as! ListViewController
        listVC.myCollectionView.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
      
      guard
        segue.identifier == "previewSegue",
        let vc = segue.destination as? PreviewViewController,
        let title = self.title,
        let body = myTextView.text,
        let image = myImageView.image
        else {
          return
      }

      let pdfCreator = PDFCreator(
        title: title,
        body: body,
        image: image
      )
      vc.documentData = pdfCreator.createPDF()
    }
    
    
}

// MARK: - RecognizedTextDataSource

@available(iOS 13.0, *)
extension ResultsViewController: RecognizedTextDataSource {
    func addRecognizedText(recognizedText: [VNRecognizedTextObservation]) {
        // Create a full transcript to run analysis on.
        let maximumCandidates = 1
        
        for observation in recognizedText  {
            
           guard let candidate = observation.topCandidates(maximumCandidates).first else { continue }
           let text = candidate.string
         
           if scannedItem.headline == "Scanned Item" && text.count >= 3 {
               // title is located generally on the top-left
                scannedItem.headline = text
           } else {
               allContent.append(text)
           }
        }
        scannedItem.content = allContent.joined(separator:" ")
        scannedItem.image = image
    }
    
}
