//
//  ViewController.swift
//  FaceDetect
//
//  Created by Simon Gladman on 24/12/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation
import CoreMedia
import Vision

class FinalFace
{
    let face: Face
    var einstein: Einstein
    let button: UIButton
    
    init(face: Face, einstein: Einstein, button: UIButton)
    {
        self.face = face
        self.einstein = einstein
        self.button = button
    }
}

func radToDeg(_ rad: CGFloat) -> CGFloat
{
    return rad * 180 / CGFloat.pi
}

extension CIFilter
{
    static let possibleFilters = [CIFilter(name: "CIComicEffect")!,
                                  CIFilter(name: "CIPhotoEffectFade")!,
                                  CIFilter(name: "CICMYKHalftone")!,
                                  CIFilter(name: "CIColorInvert")!,
                                  CIFilter(name: "CIColorPosterize")!,
                                  CIFilter(name: "CIMinimumComponent")!,
                                  CIFilter(name: "CIPhotoEffectChrome")!,
                                  CIFilter(name: "CIPhotoEffectInstant")!,
                                  CIFilter(name: "CIPhotoEffectMono")!,
                                  CIFilter(name: "CIPhotoEffectNoir")!,
                                  CIFilter(name: "CIPhotoEffectProcess")!,
                                  CIFilter(name: "CIPhotoEffectTransfer")!,
                                  CIFilter(name: "CISepiaTone")!,
                                  CIFilter(name: "CIVignette")!,
                                  CIFilter(name: "CIMedianFilter")!,
                                  CIFilter(name: "CIMotionBlur")!,
                                  CIFilter(name: "CIZoomBlur")!,
                                  CIFilter(name: "CIBloom")!,
                                  CIFilter(name: "CICrystallize")!,
                                  CIFilter(name: "CIEdges")!,
                                  CIFilter(name: "CIEdgeWork")!,
                                  CIFilter(name: "CIGloom")!,
                                  CIFilter(name: "CIHexagonalPixellate")!,
                                  CIFilter(name: "CILineOverlay")!,
                                  CIFilter(name: "CIPixellate")!,
                                  CIFilter(name: "CIPointillize")!,
                                  CIFilter(name: "CISpotLight")!,
                                  ]
    
    static func apply(_ filter: CIFilter, to image: CIImage) -> CIImage
    {
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.value(forKey: kCIOutputImageKey) as! CIImage
    }
}

class ViewController: UIViewController
{
    // MARK: - Properties
    var eaglContext: EAGLContext?
    let captureSession = AVCaptureSession()
    
    let imageView = GLKView()
    var smileCount = 0
    let eyeballImage = CIImage(image: UIImage(named: "eyeball.png")!)!
    var selectedEinstein = Einstein.einstein1
    {
        didSet
        {
            guard let image = selectedImage,
                  let ciImage = CIImage(image: image) else { return }
            process(ciImage)
        }
    }
    var selectedFilters = [CIFilter]()
    {
        didSet
        {
            guard let image = selectedImage,
                  let ciImage = CIImage(image: image) else { return }
            process(ciImage)
        }
    }
    var selectedImage: UIImage?
    var finalFaces: [FinalFace]?
    var mutatingFinalFace: FinalFace?
    
    var cameraImage: CIImage?
    var orientation: AVCaptureVideoOrientation = .portrait
    
    lazy var ciContext: CIContext =
    {
        return  CIContext(eaglContext: self.eaglContext!)
    }()
    
    lazy var detector: CIDetector =
    {
        CIDetector(ofType: CIDetectorTypeFace,
            context: self.ciContext,
            options: [
                CIDetectorAccuracy: CIDetectorAccuracyHigh,
                CIDetectorTracking: true])
    }()!
    
    lazy var videoBarButtonItem: UIBarButtonItem =
    {
        let videoBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "icVideo"), style: .plain, target: self, action: #selector(self.didPressVideo(_:)))
        return videoBarButtonItem
    }()
    
    lazy var photoImageView: UIImageView =
    {
        let photoImageView = UIImageView()
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(photoImageView)
        photoImageView.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true
        photoImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        photoImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        photoImageView.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor).isActive = true
        photoImageView.contentMode = .scaleAspectFit
        photoImageView.clipsToBounds = true
        return photoImageView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        eaglContext = EAGLContext(api: .openGLES2)
        photoImageView.isHidden = false
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds
        orientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == .authorized
        {
            initialiseCaptureSession()
        }
        else
        {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler:
            { (authorized) in
                DispatchQueue.main.async
                {
                    if authorized
                    {
                        self.initialiseCaptureSession()
                    }
                }
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let navVC = segue.destination as? UINavigationController,
           let einsteinTableViewController = navVC.viewControllers[0] as? EinsteinTableViewController
        {
            einsteinTableViewController.selectedEinstein = selectedEinstein
            einsteinTableViewController.delegate  = self
        }
        else if let navVC = segue.destination as? UINavigationController,
                let filterViewController = navVC.viewControllers[0] as? FiltersTableViewController
        {
            filterViewController.selectedFilters = selectedFilters
            filterViewController.delegate = self
        }
    }
    
    // MARK: - Setup
    private func findCamera() -> AVCaptureDevice?
    {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTelephotoCamera,
            .builtInWideAngleCamera
        ]
        
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes,
                                                         mediaType: AVMediaTypeVideo,
                                                         position: .front)
        
        return discovery?.devices.first
    }

    func initialiseCaptureSession()
    {
        guard captureSession.inputs.count == 0 else { return }
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        guard let frontCamera = findCamera() else
        {
            fatalError("Unable to access front camera")
        }
        
        do
        {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.addInput(input)
        }
        catch
        {
            fatalError("Unable to access front camera")
        }

        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
        imageView.frame = view.bounds
        view.addSubview(imageView)
        imageView.delegate = self
        if let context = eaglContext
        {
            imageView.context = context
        }
        captureSession.startRunning()
        
    }
    
    /// Detects either the left or right eye from `cameraImage` and, if detected, composites
    /// `eyeballImage` over `backgroundImage`. If no eye is detected, simply returns the
    /// `backgroundImage`.
    func eyeImage(_ cameraImage: CIImage, backgroundImage: CIImage, leftEye: Bool) -> CIImage
    {
        let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
        let transformFilter = CIFilter(name: "CIAffineTransform")!
        
        let halfEyeWidth = eyeballImage.extent.width / 2
        let halfEyeHeight = eyeballImage.extent.height / 2
        
        if let features = detector.features(in: cameraImage).first as? CIFaceFeature, leftEye ? features.hasLeftEyePosition : features.hasRightEyePosition
        {
            let eyePosition = CGAffineTransform(
                translationX: leftEye ? features.leftEyePosition.x - halfEyeWidth : features.rightEyePosition.x - halfEyeWidth,
                y: leftEye ? features.leftEyePosition.y - halfEyeHeight : features.rightEyePosition.y - halfEyeHeight)
            
            transformFilter.setValue(eyeballImage, forKey: "inputImage")
            transformFilter.setValue(NSValue(cgAffineTransform: eyePosition), forKey: "inputTransform")
            let transformResult = transformFilter.value(forKey: "outputImage") as! CIImage
                
            compositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
            compositingFilter.setValue(transformResult, forKey: kCIInputImageKey)
            
            return  compositingFilter.value(forKey: "outputImage") as! CIImage
        }
        else
        {
            return backgroundImage
        }
    }
    
    func add(faces: [VisionFace], backgroundImage: CIImage, einstein: Einstein) -> CIImage
    {
        var backgroundImage = backgroundImage
        var finalFs = [FinalFace]()
        for face in faces
        {
            let leftEyeLandmark = face.landmarks.first(where: { $0.type == .leftEye })
            let rightEyeLandmark = face.landmarks.first(where: { $0.type == .rightEye })
            
            let leftEyePoints = leftEyeLandmark?.points.map
            { point in
                return CGPoint(x: face.rect.minX + point.x * face.rect.width,
                               y: face.rect.minY + (1 - point.y) * face.rect.height)
            }
            
            let rightEyePoints = rightEyeLandmark?.points.map
            { point in
                return CGPoint(x: face.rect.minX + point.x * face.rect.width,
                               y: face.rect.minY + (1 - point.y) * face.rect.height)
            }
            
            let leftEyePath = UIBezierPath()
            
            leftEyePath.move(to:leftEyePoints?.first ?? .zero)
            leftEyePoints?.forEach { leftEyePath.addLine(to: $0) }
            let leftEyeRect = leftEyePath.cgPath.boundingBox
            
            let rightEyePath = UIBezierPath()
            rightEyePath.move(to: rightEyePoints?.first ?? .zero)
            rightEyePoints?.forEach { rightEyePath.addLine(to: $0) }
            let rightEyeRect = rightEyePath.cgPath.boundingBox
            
            let button = UIButton(frame: self.photoImageView.buttonRect(for: face, image: backgroundImage))
            self.view.addSubview(button)
            button.addTarget(self, action: #selector(self.didPressFinalFace(_:)), for: .touchUpInside)
            
            
            let face = Face(leftEyeCenter: CGPoint(x: leftEyeRect.midX, y: backgroundImage.extent.height - leftEyeRect.midY), rightEyeCenter: CGPoint(x: rightEyeRect.midX, y: backgroundImage.extent.height - rightEyeRect.midY))
            
            let finalFace = FinalFace(face: face, einstein: einstein, button: button)
            finalFs.append(finalFace)
            backgroundImage = add(face: face, backgroundImage: backgroundImage, einstein: einstein)
        }
        self.finalFaces = finalFs
        return backgroundImage
    }
    
    func add(face: Face, backgroundImage: CIImage, einstein: Einstein) -> CIImage
    {
        let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
        let transformFilter = CIFilter(name: "CIAffineTransform")!
        
        let fudgePercent: CGFloat = 0.1
        let scale = (face.eyeDistance / einstein.eyeDistance)
        let xAdjust = einstein.image.size.width * scale * fudgePercent * 0.5
        let yAdjust = einstein.image.size.height * scale * fudgePercent * 0.5
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        transform = transform.concatenating(CGAffineTransform(scaleX: 1.0 + fudgePercent, y: 1.0 + fudgePercent))
        let rotation = face.eyeAngle - einstein.eyeAngle
        
        // rotate about left eye position
        transform = transform.concatenating(CGAffineTransform(translationX: -einstein.leftEyeCenter.x * scale, y: -einstein.ciImageCoordinates(point: einstein.leftEyeCenter).y * scale))
        transform = transform.concatenating(CGAffineTransform(rotationAngle: rotation))
        
        // translate so left eye is over left eye
        transform = transform.concatenating(CGAffineTransform(translationX: face.leftEyeCenter.x, y: face.leftEyeCenter.y))
        
        transform = transform.concatenating(CGAffineTransform(translationX: -cos(rotation) * xAdjust, y: -sin(rotation) * yAdjust))
        
        transformFilter.setValue(einstein.ciImage, forKey: "inputImage")
        transformFilter.setValue(NSValue(cgAffineTransform: transform), forKey: "inputTransform")
        let transformResult = transformFilter.value(forKey: "outputImage") as! CIImage
        
        compositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
        compositingFilter.setValue(transformResult, forKey: kCIInputImageKey)
        
        return  compositingFilter.value(forKey: "outputImage") as! CIImage
    }
    
    func addFace(_ feature: CIFaceFeature, backgroundImage: CIImage, einstein: Einstein) -> CIImage
    {
        let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
        let transformFilter = CIFilter(name: "CIAffineTransform")!
        
        if feature.hasLeftEyePosition, feature.hasRightEyePosition
        {
            smileCount = feature.hasSmile ? smileCount + 1 : 0
            let einstein = smileCount > 5 ? Einstein.einstein8 : einstein
            let face = Face(leftEyeCenter: feature.leftEyePosition, rightEyeCenter: feature.rightEyePosition)
            let scale = (face.eyeDistance / einstein.eyeDistance) + 0.2
            let xAdjust = einstein.image.size.width * 0.1
            let yAdjust = einstein.image.size.height * 0.1
            var transform = CGAffineTransform(scaleX: scale, y: scale)
            let rotation = face.eyeAngle - einstein.eyeAngle
            
            // rotate about left eye position
            transform = transform.concatenating(CGAffineTransform(translationX: -einstein.leftEyeCenter.x * scale, y: -einstein.ciImageCoordinates(point: einstein.leftEyeCenter).y * scale))
            transform = transform.concatenating(CGAffineTransform(rotationAngle: rotation))

            // translate so left eye is over left eye
            transform = transform.concatenating(CGAffineTransform(translationX: face.leftEyeCenter.x, y: face.leftEyeCenter.y))
            
            transform = transform.concatenating(CGAffineTransform(translationX: -cos(rotation) * xAdjust, y: -sin(rotation) * yAdjust))
            
            transformFilter.setValue(einstein.ciImage, forKey: "inputImage")
            transformFilter.setValue(NSValue(cgAffineTransform: transform), forKey: "inputTransform")
            let transformResult = transformFilter.value(forKey: "outputImage") as! CIImage
            
            compositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
            compositingFilter.setValue(transformResult, forKey: kCIInputImageKey)
            
            
            return  compositingFilter.value(forKey: "outputImage") as! CIImage
        }
        else
        {
            return backgroundImage
        }
    }
    
    func addFaces(image: CIImage) -> CIImage
    {
        var image = image
        if let features = detector.features(in: image, options: [CIDetectorSmile: true]) as? [CIFaceFeature]
        {
            for feature in features
            {
                image = addFace(feature, backgroundImage: image, einstein: selectedEinstein)
            }
        }
        return image
    }
    
    fileprivate func process(_ ciImage: CIImage)
    {
        LandmarksService().landmarks(forImage: ciImage)
        { (result) in
            switch result
            {
            case .error(let error):
                print(error)
            case .success(let faces):
                var finalImage = self.add(faces: faces, backgroundImage: ciImage, einstein: self.selectedEinstein)
                for filter in self.selectedFilters
                {
                    finalImage = CIFilter.apply(filter, to: finalImage)
                }
                if let cgImage = self.ciContext.createCGImage(finalImage, from: ciImage.extent)
                {
                    self.photoImageView.image = UIImage(cgImage: cgImage)
                }
            }
        }
    }
    
    // MARK: - Action
    @IBAction private func didPressPhotoLibrary(_ sender: UIBarButtonItem)
    {
        imageView.isHidden = true
        photoImageView.isHidden = false
        let rightBarButtonItems: [UIBarButtonItem]? = (navigationItem.rightBarButtonItems ?? []) + [videoBarButtonItem]
        navigationItem.rightBarButtonItems = rightBarButtonItems
        let imagePickerController = UIImagePickerController()
        imagePickerController.modalPresentationStyle = .popover
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = false
        imagePickerController.popoverPresentationController?.barButtonItem = sender
        present(imagePickerController, animated: true)
    }
    
    
    @IBAction func didPressEinstein(_ sender: UIBarButtonItem)
    {
        performSegue(withIdentifier: "einstein", sender: sender)
    }
    
    @objc
    fileprivate func didPressVideo(_ sender: UIBarButtonItem)
    {
        imageView.isHidden = false
        photoImageView.isHidden = true
        let rightBarButtonItems: [UIBarButtonItem]? = Array((navigationItem.rightBarButtonItems ?? []).dropLast())
        navigationItem.rightBarButtonItems = rightBarButtonItems
    }
    
    @objc
    fileprivate func didPressFinalFace(_ sender: UIButton)
    {
        let finalFace = self.finalFaces?.first(where: { $0.button == sender })
        self.mutatingFinalFace = finalFace
        self.performSegue(withIdentifier: "einstein", sender: sender)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    {
        connection.videoOrientation = orientation
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        DispatchQueue.main.sync
        {
            self.imageView.setNeedsDisplay()
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage,
              let ciImage = CIImage(image: image) else { return }
        view.subviews.flatMap { $0 as? UIButton }.forEach { $0.removeFromSuperview() }
        selectedImage = image
        process(ciImage)
        dismiss(animated: true)
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        dismiss(animated: true)
    }
}

// MARK: - GLKViewDelegate
extension ViewController: GLKViewDelegate
{
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        guard var cameraImage = cameraImage else
        {
            return
        }
        var transform = CGAffineTransform(scaleX: -1, y: 1)
        transform = transform.concatenating(CGAffineTransform(translationX: cameraImage.extent.width, y: 0))
        cameraImage = cameraImage.applying(transform)
        
//        LandmarksService().landmarks(forImage: cameraImage)
//        { (result) in
//            switch result
//            {
//            case .error(let error):
//                print(error)
//            case .success(let faces):
//                let finalImage = self.add(faces: faces, backgroundImage: cameraImage, einstein: .einstein5)
//                self.fadeEffect.setValue(finalImage, forKey: kCIInputImageKey)
//
//                var outputImage = self.fadeEffect.value(forKey: kCIOutputImageKey) as! CIImage
//
//
//                //halftoneEffect.setValue(outputImage, forKey: kCIInputImageKey)
//                //outputImage = halftoneEffect.value(forKey: kCIOutputImageKey) as! CIImage
//                let rect = CGRect(x: 0, y: 0, width: self.imageView.drawableWidth, height: self.imageView.drawableHeight)
//                self.ciContext.draw(outputImage, in: rect, from: cameraImage.extent)
//            }
//
//        }
        
        var finalImage = addFaces(image: cameraImage)
        
        for filter in selectedFilters
        {
            finalImage = CIFilter.apply(filter, to: finalImage)
        }

        let rect = CGRect(x: 0, y: 0, width: imageView.drawableWidth, height: imageView.drawableHeight)
        self.ciContext.draw(finalImage, in: rect, from: cameraImage.extent)
        
    }
}

// MARK: - EinsteinTableViewControllerDelegate
extension ViewController: EinsteinTableViewControllerDelegate
{
    func didSelect(_ einstein: Einstein)
    {
        if let finalFace = self.mutatingFinalFace,
           let selectedImage = self.selectedImage,
           var backgroundImage = CIImage(image: selectedImage)
        {
            finalFace.einstein = einstein
            for finalFace in self.finalFaces ?? []
            {
                backgroundImage = add(face: finalFace.face, backgroundImage: backgroundImage, einstein: finalFace.einstein)
            }
            for filter in self.selectedFilters
            {
                backgroundImage = CIFilter.apply(filter, to: backgroundImage)
            }
            if let cgImage = self.ciContext.createCGImage(backgroundImage, from: backgroundImage.extent)
            {
                self.photoImageView.image = UIImage(cgImage: cgImage)
            }
            
        }
        else
        {
            selectedEinstein = einstein
        }
    }
}

// MARK: - FiltersTableViewControllerDelegate
extension ViewController: FiltersTableViewControllerDelegate
{
    func didUpdate(selectedFilters: [CIFilter])
    {
        self.selectedFilters = selectedFilters
    }
}

extension UIImageView
{
    func ciImagePointToViewPoint(point: CGPoint, image: CIImage) -> CGPoint
    {
        if image.extent.width > image.extent.height
        {
            let widthRatio = self.bounds.width / image.extent.width
            let finalX = point.x * widthRatio
            var finalY = (image.extent.height - point.y) * widthRatio
            finalY += self.bounds.height * 0.5 - image.extent.height * widthRatio * 0.5
            let offset = finalY - self.bounds.height * 0.5
            finalY = self.bounds.height * 0.5 - offset + self.frame.origin.y
            return CGPoint(x: finalX, y: finalY)
        }
        else
        {
            let heightRatio = self.bounds.height / image.extent.height
            var finalX = point.x * heightRatio
            finalX += (self.bounds.width - image.extent.width * heightRatio) / 2.0
            
            var finalY = (image.extent.height - point.y) * heightRatio
            finalY += self.frame.origin.x
            
            return CGPoint(x: finalX, y: finalY)
        }
        
    }
    
    func buttonRect(for face: VisionFace, image: CIImage) -> CGRect
    {
        let origin = ciImagePointToViewPoint(point: face.rect.origin, image: image)
        if image.extent.width > image.extent.height
        {
            let widthRatio = self.bounds.width / image.extent.width
            let rect = CGRect(x: origin.x, y: origin.y, width: face.rect.width * widthRatio, height: face.rect.height * widthRatio)
            return rect
        }
        else
        {
            let heightRatio = self.bounds.height / image.extent.height
            let rect = CGRect(x: origin.x, y: origin.y, width: face.rect.width * heightRatio, height: face.rect.height * heightRatio)
            return rect
        }
        
    }
}





