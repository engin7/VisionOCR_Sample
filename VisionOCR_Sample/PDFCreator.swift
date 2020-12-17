//
//  PDFCreator.swift
//  VisionOCR_Sample
//
//  Created by Engin KUK on 17.12.2020.
//

import Foundation
import PDFKit

class PDFCreator: NSObject {
    
    let title: String
    let body: String
    let image: UIImage
    
    init(title: String, body: String, image: UIImage, contact: String) {
      self.title = title
      self.body = body
      self.image = image
    }
    
    func createPDF() -> Data {
        
        let pdfMetaData = [
          kCGPDFContextCreator: "Bill OCR",
          kCGPDFContextAuthor: "CloudApper",
          kCGPDFContextTitle: title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        //  pdf files use coordinate system 72 px per inch. You can create U.S. letter size
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        // create a PDFRenderer object with settings you made above
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
          //  starts new pdf page (call it more to create multiple pages)
          context.beginPage()
          let titleBottom = addTitle(pageRect: pageRect)
          // add a half-inch of space between the title and body text.
          let bodyBottom = addBodyText(pageRect: pageRect, textTop: titleBottom + 18.0)
          addImage(pageRect: pageRect, imageTop: bodyBottom + 18.0)
        
        }

        return data
        
    }
    
    //MARK: - Adding Title (CoreText)
    
    func addTitle(pageRect: CGRect) -> CGFloat {
      //  create instance of System font
      let titleFont = UIFont.systemFont(ofSize: 18.0, weight: .bold)
      let titleAttributes: [NSAttributedString.Key: Any] =
        [NSAttributedString.Key.font: titleFont]
      //  you create NSAttributedString containing the text of the title in the chosen font.
      let attributedTitle = NSAttributedString(
        string: title,
        attributes: titleAttributes
      )
      //  Using size() on the attributed string returns a rectangle with the size the text will occupy in the current context.
      let titleStringSize = attributedTitle.size()
      //   using additional layout functionality provided by Core Text.
      let titleStringRect = CGRect(
        x: (pageRect.width - titleStringSize.width) / 2.0, // centering
        y: 36,
        width: titleStringSize.width,
        height: titleStringSize.height
      )
      //  draw inside the rectangle
      attributedTitle.draw(in: titleStringRect)
      //  find the coordinate of the bottom of the rectangle and return
      return titleStringRect.origin.y + titleStringRect.size.height
    }
    
    //MARK: - Adding BodyText (NSParagraphStyle)
    
    func addBodyText(pageRect: CGRect, textTop: CGFloat) -> CGFloat {
      let textFont = UIFont.systemFont(ofSize: 12.0, weight: .regular)
      // Natural alignment sets the alignment based on the localization of the app.
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.alignment = .natural
      paragraphStyle.lineBreakMode = .byWordWrapping // Lines are set to wrap at word breaks.
     
      let textAttributes = [
        NSAttributedString.Key.paragraphStyle: paragraphStyle,
        NSAttributedString.Key.font: textFont
      ]
      let attributedText = NSAttributedString(
        string: body,
        attributes: textAttributes
      )
      //  offsets 10 points from the left and sets the top at the passed value. The width is set to the width of the page minus a margin of 10 points on each side. The height is the distance from the top to 1/5 of the page height from the bottom.
      let textRect = CGRect(
        x: 10,
        y: textTop,
        width: pageRect.width - 20,
        height: pageRect.height - textTop - pageRect.height / 5.0
      )
      attributedText.draw(in: textRect)
        return textRect.origin.y + textRect.size.height
    }
    
    //MARK: - Adding Images to PDF
    
    func addImage(pageRect: CGRect, imageTop: CGFloat) {
       
      let maxHeight = pageRect.height * 0.4
      let maxWidth = pageRect.width * 0.8
      // This ratio maximizes the size of the image while ensuring that it fits within the constraints.
      let aspectWidth = maxWidth / image.size.width
      let aspectHeight = maxHeight / image.size.height
      let aspectRatio = min(aspectWidth, aspectHeight)
      // Calculate the scaled height and width for the image using the ratio.
      let scaledWidth = image.size.width * aspectRatio
      let scaledHeight = image.size.height * aspectRatio
      // Calculate the horizontal offset to center the image, just as you did earlier with the title text. Create a rectangle at this coordinate with the size you’ve calculated.
      let imageX = (pageRect.width - scaledWidth) / 2.0
      let imageRect = CGRect(x: imageX, y: imageTop,
                             width: scaledWidth, height: scaledHeight)
      // This method scales the image to fit within the rectangle. Finally, return the coordinate of the bottom of the image to the caller, just as you did with the title text.
      image.draw(in: imageRect)
      
    }
    
    
    
}
