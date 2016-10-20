//
//  ViewController.swift
//  AccessCameraPixels
//
//  Created by Stijn Oomes on 18/10/2016.
//  Copyright © 2016 Oomes Vision Systems. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var processView: UIImageView!
    
    var cameraDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPreset640x480

        let videoDeviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)

        if let deviceDiscovery = videoDeviceDiscoverySession {
            for camera in deviceDiscovery.devices as [AVCaptureDevice] {
                if camera.position == .back {
                    cameraDevice = camera
                }
            }
            if cameraDevice == nil {
                print("Could not find back camera.")
            }
        }
        
        if let cam = cameraDevice {
            let frameRateRange = cam.activeFormat.videoSupportedFrameRateRanges[0] as! AVFrameRateRange
            do {
                try cam.lockForConfiguration()
                cam.activeVideoMinFrameDuration = frameRateRange.maxFrameDuration
                cam.unlockForConfiguration()
            } catch {
                print("Could not set frame duration.")
                return
            }
        }

        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: cameraDevice)            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            }
        } catch {
            print("Could not add camera as input: \(error)")
            return
        }

        if let previewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession) {
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            previewLayer.frame = cameraPreview.bounds
            if previewLayer.connection.isVideoOrientationSupported {
                previewLayer.connection.videoOrientation = .landscapeRight
            }
            cameraPreview.layer.addSublayer(previewLayer)
        } else {
            print("Could not add video preview layer.")
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Could not add video data as output.")
        }

        // start session
        captureSession.startRunning()
    }

    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bitsPerComponent = 8
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)!
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        for j in 0..<height {
            for i in 0..<width {
                let index = (j * width + i) * 4
                
                let b = byteBuffer[index]
                let g = byteBuffer[index+1]
                let r = byteBuffer[index+2]
                //let a = byteBuffer[index+3]
                
                if r > UInt8(128) && g < UInt8(128) {
                    byteBuffer[index] = UInt8(255)
                    byteBuffer[index+1] = UInt8(0)
                    byteBuffer[index+2] = UInt8(0)
                } else {
                    byteBuffer[index] = g
                    byteBuffer[index+1] = r
                    byteBuffer[index+2] = b
                }
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        if let context = newContext {
            let cameraFrame = context.makeImage()
            DispatchQueue.main.async {
                self.processView.image = UIImage(cgImage: cameraFrame!)
            }
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
    }
}

