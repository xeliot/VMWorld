//
//  ViewController.swift
//  VMWorld
//
//  Created by Dave Ho on 7/24/18.
//  Copyright © 2018 Dave Ho. All rights reserved.
//

import UIKit
import Alamofire

struct RGBA32: Equatable {
    private var color: UInt32
    
    var redComponent: UInt8 {
        return UInt8((color >> 24) & 255)
    }
    
    var greenComponent: UInt8 {
        return UInt8((color >> 16) & 255)
    }
    
    var blueComponent: UInt8 {
        return UInt8((color >> 8) & 255)
    }
    
    var alphaComponent: UInt8 {
        return UInt8((color >> 0) & 255)
    }
    
    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let red   = UInt32(red)
        let green = UInt32(green)
        let blue  = UInt32(blue)
        let alpha = UInt32(alpha)
        color = (red << 24) | (green << 16) | (blue << 8) | (alpha << 0)
    }
    
    static let red     = RGBA32(red: 255, green: 0,   blue: 0,   alpha: 255)
    static let green   = RGBA32(red: 0,   green: 255, blue: 0,   alpha: 255)
    static let blue    = RGBA32(red: 0,   green: 0,   blue: 255, alpha: 255)
    static let white   = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
    static let black   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 255)
    static let magenta = RGBA32(red: 255, green: 0,   blue: 255, alpha: 255)
    static let yellow  = RGBA32(red: 255, green: 255, blue: 0,   alpha: 255)
    static let cyan    = RGBA32(red: 0,   green: 255, blue: 255, alpha: 255)
    
    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    
    static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
        return lhs.color == rhs.color
    }
}

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {

    @IBOutlet weak var photoImage: UIImageView!
    @IBOutlet weak var predictedNumber: UILabel!
    @IBOutlet weak var apiURL: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.photoImage.image = UIImage(named: "Loading")
        // Do any additional setup after loading the view, typically from a nib.
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.apiURL.delegate = self
        self.hideKeyboardWhenTappedAround()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    @IBAction func takePhoto(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerController.SourceType.camera
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        var pickedImage: UIImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        //pickedImage = squareImage(image: pickedImage)
        self.photoImage.image = UIImage(named: "Processing")
        picker.dismiss(animated: true, completion: { () in
            pickedImage = pickedImage.noir
            pickedImage = self.processPixels(in: pickedImage)!
            pickedImage = pickedImage.resized(toWidth: 28.0)!
            self.photoImage.contentMode = .scaleAspectFill
            self.photoImage.image = pickedImage
        })
        print("camera was dismissed")
    }
    
    func processPixels(in image: UIImage) -> UIImage? {
        guard let inputCGImage = image.cgImage else {
            print("unable to get cgImage")
            return nil
        }
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context.data else {
            print("unable to get context data")
            return nil
        }
        
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                pixelBuffer[offset] = RGBA32(red: 255-pixelBuffer[offset].redComponent, green: 255-pixelBuffer[offset].greenComponent,   blue: 255-pixelBuffer[offset].blueComponent,   alpha: 255)
                if ((pixelBuffer[offset].redComponent < 210) && (pixelBuffer[offset].greenComponent < 210) && (pixelBuffer[offset].blueComponent < 210)) {
                    pixelBuffer[offset] = .black
                }
            }
        }
        
        let outputCGImage = context.makeImage()!
        let outputImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        
        return outputImage
    }
    
    func pixelArray(in image: UIImage) -> [[Float]]? {
        guard let inputCGImage = image.cgImage else {
            print("unable to get cgImage")
            return nil
        }
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context.data else {
            print("unable to get context data")
            return nil
        }
        
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
        
        var fullArray = [[Float]]()
        
        for row in 0 ..< Int(height) {
            var rowArray = [Float]()
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                /*
                print("red")
                print(pixelBuffer[offset].redComponent)
                print("green")
                print(pixelBuffer[offset].greenComponent)
                print("blue")
                print(pixelBuffer[offset].blueComponent)
                print("offset")
                print(offset)
                */
                rowArray.append(Float(pixelBuffer[offset].redComponent))
            }
            fullArray.append(rowArray)
        }
        
        return fullArray
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0{
                self.view.frame.origin.y -= 210
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y != 0{
                self.view.frame.origin.y += 210
            }
        }
    }
    
    @IBAction func predictNumber(_ sender: UIButton) {
        
        let bitmap = pixelArray(in: photoImage.image!)!
        print(bitmap)
        let parameters: Parameters = ["data": bitmap]
        var url:String;
        if (apiURL.text!.isEmpty){
            url = "http://192.168.1.17:5000/mlaas/mnist"
        }else{
            url = "http://" + apiURL.text! + ":5000/mlaas/mnist"
        }
        Alamofire.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON{ response in
            if let result = response.result.value {
                
                let JSON = (result as! NSDictionary)
                let result = JSON["result"] as! String
                self.predictedNumber.text = "Predicted " + result
            }
        }
 
        //let imageData = photoImage.image!.pngData()!
        
        //Alamofire.upload(imageData, to: "http://192.168.1.17:5000/mlaas/mnist").responseString { response in
        //    print(response)
        //}
        /*
        Alamofire.upload(multipartFormData: { formData in
            formData.append(imageData, withName: "image", fileName: "image.png", mimeType: "image/png")
        }, to: "http://192.168.1.17:5000/mlaas/mnist", encodingCompletion: { result in
            switch result {
            case .success(let upload, _, _):
                upload.validate().responseString(completionHandler: { response in
                    switch response.result {
                    case .success(let value): print("success: \(value)")
                    case .failure((let error)): print("response error \(error)")
                    }
                })
            case .failure(let error):
                print("encoding error \(error)")
            }
        })
        */
    }
}

extension UIImage {
    func resized(withPercentage percentage: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    func resized(toWidth width: CGFloat) -> UIImage? {
        //let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        let canvasSize = CGSize(width: width, height: width)
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    var noir: UIImage! {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        if let output = currentFilter.outputImage,
            let cgImage = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
        }
        return nil
    }
}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
