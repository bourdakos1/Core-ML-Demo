//
//  CameraView.swift
//  Visual Recognition
//
//  Created by Nicholas Bourdakos on 3/17/17.
//  Copyright © 2017 Nicholas Bourdakos. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    // Set the StatusBar color.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // Camera variables.
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet var cameraView: UIView!
    @IBOutlet var tempImageView: UIImageView!
    
    // All the buttons.
    @IBOutlet var captureButton: UIButton!
    @IBOutlet var retakeButton: UIButton!
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start up the camera.
        initializeCamera()

        // Retake just resets the UI.
        retake()
    }
    
    // Initialize camera.
    func initializeCamera() {
        // Standard camera setup mumbo jumbo.
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            captureSession?.addInput(input)
            photoOutput = AVCapturePhotoOutput()
            if (captureSession?.canAddOutput(photoOutput!) != nil){
                captureSession?.addOutput(photoOutput!)
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                cameraView.layer.addSublayer(previewLayer!)
                captureSession?.startRunning()
            }
        } catch {
            print("Error: \(error)")
        }
        previewLayer?.frame = view.bounds
    }
    
    // Delegate for camera.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error: \(error)")
            return
        }
        
        // jpegPhotoDataRepresentation has been depricated in iOS 11.
        let photoData = photo.fileDataRepresentation()
        
        let dataProvider  = CGDataProvider(data: photoData! as CFData)
        
        let cgImageRef = CGImage(
            jpegDataProviderSource: dataProvider!,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
        
//        classify(cgImageRef!) { data in
//            // "push" pushes our data to our ResultsTableViewController.
//            self.push(data: data)
//        }
        
        let image = UIImage(data: photoData!)!
        
//        let image = UIImage(named: "dog.jpg")!
        
        let buffer = image.buffer()!
        guard let output = try? YOLO().predict(image: buffer) else {
            print("failed")
            return
        }
        
        for i in 0..<10 {
            if i < output.count {
                let prediction = output[i]
                
                let width = view.bounds.width
                let height = width * 4 / 3
                let scaleX = width / 416
                let scaleY = height / 416
                let top = (view.bounds.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                let testView = UIView(frame: rect)
                testView.backgroundColor = UIColor.red
                testView.alpha=0.5
                self.view.addSubview(testView)
                
                print(rect)
                print(prediction.score * 100)
            }
        }
        
        
        tempImageView.image = image
        tempImageView.isHidden = false
    }
    
    // Classification method.
    func classify(_ image: CGImage, completion: @escaping ([VNClassificationObservation]) -> Void) {
//        DispatchQueue.global(qos: .background).async {
//            // Initialize the coreML vision model, you can also use VGG16().model, or any other model that takes an image.
//            guard let vnCoreModel = try? VNCoreMLModel(for: Yolo().model) else { return }
//
//            // Build the coreML vision request.
//            let request = VNCoreMLRequest(model: vnCoreModel) { (request, error) in
//                // We get get an array of VNClassificationObservations back
//                // This has the fields "confidence", which is the score
//                // and "identifier" which is the recognized class
//                guard var results = request.results as? [VNClassificationObservation] else { fatalError("Failure") }
//
//                print(results)
//
//                // Filter out low scoring results.
////                results = results.filter({ $0.confidence > 0.01 })
//
////                DispatchQueue.main.async {
////                    completion(results)
////                }
//            }
//
//            // Initialize the coreML vision request handler.
//            let handler = VNImageRequestHandler(cgImage: image)
//
//            // Perform the coreML vision request.
//            do {
//                try handler.perform([request])
//            } catch {
//                print("Error: \(error)")
//            }
//        }
    }
    
    // Convenience method for closing the TableView.
    func dismissResults() {
        getTableController { tableController, drawer in
            drawer.setDrawerPosition(position: .closed, animated: true)
            tableController.classifications = []
        }
    }
    
    // Convenience method for closing the TableView.
    func push(data: [VNClassificationObservation]) {
        getTableController { tableController, drawer in
            tableController.classifications = data
            self.dismiss(animated: false, completion: nil)
            drawer.setDrawerPosition(position: .partiallyRevealed, animated: true)
        }
    }
    
    // Convenience method for pushing data to the TableView.
    func getTableController(run: (_ tableController: ResultsTableViewController, _ drawer: PulleyViewController) -> Void) {
        if let drawer = self.parent as? PulleyViewController {
            if let tableController = drawer.drawerContentViewController as? ResultsTableViewController {
                run(tableController, drawer)
                tableController.tableView.reloadData()
            }
        }
    }
    
    @IBAction func takePhoto() {
        photoOutput?.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        captureButton.isHidden = true
        retakeButton.isHidden = false
        
//        // Show an activity indicator while its loading.
//        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
//
//        alert.view.tintColor = UIColor.black
//        let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50)) as UIActivityIndicatorView
//        loadingIndicator.hidesWhenStopped = true
//        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
//        loadingIndicator.startAnimating()
//
//        alert.view.addSubview(loadingIndicator)
//        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func retake() {
        tempImageView.isHidden = true
        captureButton.isHidden = false
        retakeButton.isHidden = true
        dismissResults()
    }
}

extension UIImage {
    
    func buffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        
        let width = Int(416)
        let height = Int(416)
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue:0))
        
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer!), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: colorspace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        
        bitmapContext.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelBuffer
    }
}
