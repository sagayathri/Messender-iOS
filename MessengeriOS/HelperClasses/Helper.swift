//
//  Helper.swift
//  MessengeriOS
//

import UIKit

extension UIView {
    //Smoothens the corners
    func smoothRoundCorners(to radius: CGFloat) {
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(
          roundedRect: bounds,
          cornerRadius: radius
        ).cgPath

        layer.mask = maskLayer
    }
}

extension UIScrollView {
    var isAtBottom: Bool {
        return contentOffset.y >= verticalOffsetForBottom
    }

    var verticalOffsetForBottom: CGFloat {
    let scrollViewHeight = bounds.height
    let scrollContentSizeHeight = contentSize.height
    let bottomInset = contentInset.bottom
    let scrollViewBottomOffset = scrollContentSizeHeight + bottomInset - scrollViewHeight
    return scrollViewBottomOffset
    }
}

extension UIColor {
    static var primary: UIColor {
        return UIColor(named: "primaryColor")!
    }
  
    static var incomingMessage: UIColor {
        return UIColor.lightGray
    }
}

extension UIImage {
    var scaledToSafeUploadSize: UIImage? {
        let maxImageSideLength: CGFloat = 480

        let largerSide: CGFloat = max(size.width, size.height)
        let ratioScale: CGFloat = largerSide > maxImageSideLength ? largerSide / maxImageSideLength : 1
        let newImageSize = CGSize(width: size.width / ratioScale, height: size.height / ratioScale)

        return image(scaledTo: newImageSize)
    }
  
    func image(scaledTo size: CGSize) -> UIImage? {
        defer {
            UIGraphicsEndImageContext()
        }

        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        draw(in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

