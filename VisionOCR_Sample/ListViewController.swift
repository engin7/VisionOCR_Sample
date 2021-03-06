//
//  ListViewController.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 16.12.2020.
//

import UIKit
import Vision

@available(iOS 13.0, *)
protocol RecognizedTextDataSource: AnyObject {
    func addRecognizedText(recognizedText: [VNRecognizedTextObservation])
}

@available(iOS 13.0, *)
var textRecognitionRequest = VNRecognizeTextRequest()
 
class ListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
   
    static let resultsContentsIdentifier = "resultsVC"
    static let collectionViewReuseIdentifier = "Cell"
    
    @IBOutlet weak var myCollectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBAction func scanButtonPressed(_ sender: Any) {
        present(picker, animated: true, completion: nil)
    }
    
    let picker = UIImagePickerController()
    var resultsViewController: ResultsViewController?
    var scannedItems:[ScannedItem] = []
    var lastFlashMode = UIImage(named:"bolt.badge.a")
    var cameraVC:CameraViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        picker.delegate = self
        picker.sourceType = .photoLibrary
        
        if #available(iOS 13.0, *) {
            configureVNText()
        } else {
            // Fallback on earlier versions
        }
       
    }
  
    @available(iOS 13.0, *)
    func configureVNText() {

        textRecognitionRequest = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true // default is EN
        // can add customWords if needed: https://developer.apple.com/documentation/vision/vnrecognizetextrequest/3152640-customwords
//        let customWords = ["on","off"]
//        textRecognitionRequest.customWords = customWords
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let scannedItem = dataBase[indexPath.row]
 
        if let index = self.myCollectionView.indexPathsForSelectedItems?.first {
            
        resultsViewController = storyboard?.instantiateViewController(withIdentifier: ListViewController.resultsContentsIdentifier) as? ResultsViewController
       
        if let resultsVC = self.resultsViewController {
            resultsVC.scannedItem = scannedItem
            resultsVC.selectedIndex = index
            self.navigationController?.pushViewController(resultsVC, animated: true)
        }
        }
    }
    // just before segue to camera
        override  func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if type(of:segue.destination) == type(of:CameraViewController()) {
                cameraVC = segue.destination as? CameraViewController
                cameraVC?.delegate = self
            }
        }
    
    // MARK: - VNImageRequestHandler
    @available(iOS 13.0, *)
    func processImage(image: UIImage?) {
        guard let cgImage = image?.cgImage else {
            print("Failed to get cgimage from input image")
            return
        }
        // image-request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        //  created new request to recognize text: var textRecognitionRequest = VNRecognizeTextRequest()
        do {
            try handler.perform([textRecognitionRequest]) // perform the request *accurate path is default
        } catch {
            print(error)
        }
    }
    
    @available(iOS 13.0, *)
    func processImageFromCam(image: UIImage?) {
        guard let cgImage = image?.cgImage else {
            print("Failed to get cgimage from input image")
            return
        }
        // image-request handler
        let handler = VNImageRequestHandler(cgImage: cgImage)
        //  created new request to recognize text: var textRecognitionRequest = VNRecognizeTextRequest()
        do {
            try handler.perform([textRecognitionRequest]) // perform the request *accurate path is default
        } catch {
            print(error)
        }
    }
    
    
    @available(iOS 13.0, *)
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let resultsViewController = self.resultsViewController else {
            print("resultsViewController is not set")
            return
        }
        if let results = request.results, !results.isEmpty {
            if let requestResults = request.results as? [VNRecognizedTextObservation] {
                DispatchQueue.main.async {
                    resultsViewController.addRecognizedText(recognizedText: requestResults)
                }
            }
        }
    }
    
}
 

// MARK: UICollectionViewDelegateFlowLayout

extension ListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let height: CGFloat
        var width: CGFloat
        // two rows for ipad
        if collectionView.frame.size.width < 768 {
            width  = collectionView.frame.width/2 - 20
            height = collectionView.frame.width/2 - 20
        } else {
            width  = collectionView.frame.width/3 - 50
            height = collectionView.frame.width/3 - 90
        }
        return CGSize(width: width, height: height)
    }
}
// MARK: - Image from Library

 extension ListViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
     
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        let vcID = ListViewController.resultsContentsIdentifier
            resultsViewController = storyboard?.instantiateViewController(withIdentifier: vcID) as? ResultsViewController
             
            self.activityIndicator.startAnimating()
        
        if let pickedImage = info[.originalImage] as? UIImage {
            DispatchQueue.global(qos: .userInitiated).async {
                //  VNImageRequestHandler
                if let resultsVC = self.resultsViewController {
                    resultsVC.image = pickedImage
                }
                if #available(iOS 13.0, *) {
                    self.processImage(image: pickedImage)
                } else {
                    // Fallback on earlier versions
                }
                
                DispatchQueue.main.async {
                    if let resultsVC = self.resultsViewController {
                        self.navigationController?.pushViewController(resultsVC, animated: true)
                    }
                    self.activityIndicator.stopAnimating()
                }
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
        
        }
}

extension ListViewController: CameraViewControllerDelegate {
    
    func proceedFromCamera(image: UIImage?) {
       
        let vcID = ListViewController.resultsContentsIdentifier
            resultsViewController = storyboard?.instantiateViewController(withIdentifier: vcID) as? ResultsViewController
             
        if let resultsVC = self.resultsViewController {
            resultsVC.image = image
        }
        if #available(iOS 13.0, *) {
            self.processImageFromCam(image: image)
        } else {
            // Fallback on earlier versions
        }
        
        DispatchQueue.main.async {
            if let resultsVC = self.resultsViewController {
                self.navigationController?.pushViewController(resultsVC, animated: true)
            }
         }
    }
}
 
