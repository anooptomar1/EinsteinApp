//
//  Einstein.swift
//  FaceDetect
//
//  Created by B Gay on 8/9/17.
//  Copyright © 2017 Simon Gladman. All rights reserved.
//

import UIKit
import CoreImage

protocol EyeMath
{
    var leftEyeCenter: CGPoint { get }
    var rightEyeCenter: CGPoint { get }
}

extension EyeMath
{
    var eyeDistance: CGFloat
    {
        return sqrt(pow(rightEyeCenter.x - leftEyeCenter.x, 2) + pow(rightEyeCenter.y - leftEyeCenter.y, 2))
    }
    
    var eyeAngle: CGFloat
    {
        return atan((rightEyeCenter.y - leftEyeCenter.y) / (rightEyeCenter.x - leftEyeCenter.x))
    }
}

struct Face: EyeMath
{
    let leftEyeCenter: CGPoint
    let rightEyeCenter: CGPoint
}

struct Einstein: EyeMath
{
    let image: UIImage
    let leftEyeCenter: CGPoint
    let rightEyeCenter: CGPoint
    static let einstein1 = Einstein(image: #imageLiteral(resourceName: "eistein1"), leftEyeCenter: CGPoint(x: 149, y: 222), rightEyeCenter: CGPoint(x: 254, y: 222))
    static let einstein2 = Einstein(image: #imageLiteral(resourceName: "einstein2"), leftEyeCenter: CGPoint(x: 87, y: 138), rightEyeCenter: CGPoint(x: 158, y: 142))
    static let einstein3 = Einstein(image: #imageLiteral(resourceName: "einstein3"), leftEyeCenter: CGPoint(x: 224, y: 271), rightEyeCenter: CGPoint(x: 318, y: 273))
    static let einstein4 = Einstein(image: #imageLiteral(resourceName: "einstein4"), leftEyeCenter: CGPoint(x: 237, y: 217), rightEyeCenter: CGPoint(x: 334, y: 225))
    static let einstein5 = Einstein(image: #imageLiteral(resourceName: "einstein5"), leftEyeCenter: CGPoint(x: 128, y: 288), rightEyeCenter: CGPoint(x: 255, y: 286))
    static let einstein6 = Einstein(image: #imageLiteral(resourceName: "einstein6"), leftEyeCenter: CGPoint(x: 854, y: 1037), rightEyeCenter: CGPoint(x: 1198, y: 1041))
    static let einstein7 = Einstein(image: #imageLiteral(resourceName: "einstein7"), leftEyeCenter: CGPoint(x: 70, y: 151), rightEyeCenter: CGPoint(x: 127, y: 144))
    static let einstein8 = Einstein(image: #imageLiteral(resourceName: "einstein8"), leftEyeCenter: CGPoint(x: 150, y: 140), rightEyeCenter: CGPoint(x: 232, y: 144))
    
    static let all: [Einstein] = [.einstein1, .einstein2, .einstein3, .einstein4, .einstein5, .einstein6, .einstein7, .einstein8]
    
    var ciImage: CIImage
    {
        return CIImage(image: image)!
    }
    
    func ciImageCoordinates(point: CGPoint) -> CGPoint
    {
        return CGPoint(x: point.x, y: image.size.height - point.y)
    }
    
    var verticalDiff: CGFloat
    {
        return (ciImageCoordinates(point: rightEyeCenter).y - ciImageCoordinates(point: leftEyeCenter).y)
    }
    
    var horizontalDiff: CGFloat
    {
        return (rightEyeCenter.x - leftEyeCenter.x)
    }
    
    var eyeAngle: CGFloat
    {
        return atan(verticalDiff / horizontalDiff)
    }
    
    func horizontalRotationOffset(rotation: CGFloat, scale: CGFloat) -> CGFloat
    {
        return cos(rotation) * leftEyeCenter.x * scale
    }
    
    func verticalRotationOffset(rotation: CGFloat, scale: CGFloat) -> CGFloat
    {
        return sin(rotation) * leftEyeCenter.x * scale
    }
}

extension Einstein: Equatable
{
    static func ==(lhs: Einstein, rhs: Einstein) -> Bool
    {
        return lhs.leftEyeCenter == rhs.leftEyeCenter && lhs.rightEyeCenter == rhs.rightEyeCenter
    }
}

