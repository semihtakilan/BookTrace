//
//  BarcodeScannerView.swift
//  Explore
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import AVFoundation
import AudioToolbox
import SwiftUI
import UIKit

/// Barkod tarama sayfası.
///
/// Kameranın varlığı ve izin durumu, yakalama oturumu kurulmadan **önce**
/// SwiftUI tarafında belirlenir ve sonuç bu sayfanın içinde gösterilir. Daha
/// önce bu kontrol `UIViewController.viewDidLoad` içinde yapılıyordu: sayfa
/// sunulurken hata geri bildirilince hem sheet kapatılıyor hem alert açılmaya
/// çalışılıyordu, UIKit ikisini aynı anda yapamadığı için sheet anında düşüyordu.
struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accessState: CameraAccessState = .checking
    @State private var sessionErrorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scan Barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .task { accessState = await CameraAccessState.resolve() }
    }

    @ViewBuilder
    private var content: some View {
        switch accessState {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            ZStack {
                CameraPreviewView(
                    onScan: { barcode in
                        onScan(barcode)
                        dismiss()
                    },
                    onError: { message in sessionErrorMessage = message }
                )
                .ignoresSafeArea(edges: .bottom)

                if let sessionErrorMessage {
                    Text(sessionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.7), in: .rect(cornerRadius: 10))
                        .padding()
                } else {
                    scanGuide
                }
            }

        case .denied:
            ContentUnavailableView {
                Label("Camera access is off", systemImage: "camera.fill")
            } description: {
                Text("BookTrace needs the camera to read a book's barcode. You can turn it on in Settings.")
            } actions: {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }

        case .unavailable:
            ContentUnavailableView {
                Label("No camera available", systemImage: "camera.metering.unknown")
            } description: {
                Text("This device has no camera to scan with. On the Simulator, search by title or ISBN instead.")
            }
        }
    }

    /// Kullanıcıya barkodu nereye tutacağını gösteren çerçeve.
    private var scanGuide: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.85), lineWidth: 3)
                .frame(height: 160)
                .padding(.horizontal, 40)
            Text("Point the camera at the barcode on the back cover")
                .font(.footnote)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }
}

/// Kameranın kullanılabilirliği — oturum kurulmadan önce belirlenir.
enum CameraAccessState {
    case checking
    case ready
    case denied
    case unavailable

    static func resolve() async -> CameraAccessState {
        guard AVCaptureDevice.default(for: .video) != nil else { return .unavailable }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .ready
        case .notDetermined:
            // Sistem izin sorusu tam da burada, sayfa açıkken sorulur.
            return await AVCaptureDevice.requestAccess(for: .video) ? .ready : .denied
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
}

/// Yalnızca kamera var ve izin verilmişken oluşturulur.
private struct CameraPreviewView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        private let parent: CameraPreviewView

        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }

        func didFindBarcode(_ barcode: String) {
            parent.onScan(barcode)
        }

        func didFail(with error: Error) {
            parent.onError(error.localizedDescription)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindBarcode(_ barcode: String)
    func didFail(with error: Error)
}

final class ScannerViewController: UIViewController {
    weak var delegate: ScannerViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDeliveredBarcode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSessionIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func configureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            report(.noCameraAvailable)
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            report(error)
            return
        }

        guard captureSession.canAddInput(videoInput) else {
            report(.cannotAddInput)
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            report(.cannotAddOutput)
            return
        }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

        // Desteklenmeyen bir tip atamak AVFoundation'da exception fırlatıyor;
        // bu yüzden istediklerimizi donanımın sunduklarıyla kesiştiriyoruz.
        let wantedTypes: [AVMetadataObject.ObjectType] = [.ean13, .ean8]
        metadataOutput.metadataObjectTypes = wantedTypes
            .filter(metadataOutput.availableMetadataObjectTypes.contains)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func startSessionIfNeeded() {
        guard !captureSession.isRunning, !captureSession.inputs.isEmpty else { return }
        // `startRunning` bloklayıcıdır; ana kuyrukta çağrılmamalı.
        Task.detached(priority: .userInitiated) { [captureSession] in
            captureSession.startRunning()
        }
    }

    /// Hata bildirimini bir sonraki döngüye erteler: `viewDidLoad` sayfa
    /// sunulurken çalışıyor ve o an SwiftUI durumunu değiştirmek sunumu bozuyor.
    private func report(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didFail(with: error)
        }
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Kamera saniyede onlarca kare üretiyor; ilk okumadan sonrasını yok sayıyoruz.
        guard !hasDeliveredBarcode,
              let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        hasDeliveredBarcode = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        captureSession.stopRunning()
        delegate?.didFindBarcode(stringValue)
    }
}

enum ScannerError: Error, LocalizedError {
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: "This device has no camera."
        case .cannotAddInput:    "The camera input could not be added."
        case .cannotAddOutput:   "The camera output could not be added."
        }
    }
}

private extension ScannerViewController {
    func report(_ error: ScannerError) {
        report(error as Error)
    }
}
