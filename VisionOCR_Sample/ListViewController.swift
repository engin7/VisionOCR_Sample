//
//  ListViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 16.12.2020.
//

import UIKit
import Vision

protocol RecognizedTextDataSource: AnyObject {
    func addRecognizedText(recognizedText: [VNRecognizedTextObservation])
}

class ListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
   
    static let resultsContentsIdentifier = "resultsVC"
    static let collectionViewReuseIdentifier = "Cell"
    
    @IBAction func scanButtonPressed(_ sender: Any) {
        present(picker, animated: true, completion: nil)
    }
    
    var textRecognitionRequest = VNRecognizeTextRequest()
    let picker = UIImagePickerController()
    var resultsViewController: ResultsViewController?
    var scannedItems:[Scan] = []
  

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataBase.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ListViewController.collectionViewReuseIdentifier, for: indexPath) as! ListCollectionViewCell

        let item = dataBase[indexPath.row]
        cell.imageView.image = item.image
        cell.label.text = item.headline
        
        return cell
    }

}

