//
//  BarcodeScannerView.swift
//  Explore
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onError: ((Error) -> Void)?

    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerViewController = ScannerViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        let parent: BarcodeScannerView

        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }

        func didFindBarcode(_ barcode: String) {
            parent.onScan(barcode)
        }

        func didFail(with error: Error) {
            parent.onError?(error)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindBarcode(_ barcode: String)
    func didFail(with error: Error)
}

final class ScannerViewController: UIViewController {
    weak var delegate: ScannerViewControllerDelegate?
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFail(with: ScannerError.noCameraAvailable)
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFail(with: error)
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFail(with: ScannerError.cannotAddInput)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr]
        } else {
            delegate?.didFail(with: ScannerError.cannotAddOutput)
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // Stop running after a successful scan to prevent multiple firings
            captureSession.stopRunning()
            
            delegate?.didFindBarcode(stringValue)
        }
    }
}

enum ScannerError: Error, LocalizedError {
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    
    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: return "Bu cihazda kamera bulunmuyor."
        case .cannotAddInput: return "Kamera girişi eklenemedi."
        case .cannotAddOutput: return "Kamera çıkışı eklenemedi."
        }
    }
}
