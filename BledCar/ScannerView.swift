//
//  ScannerView.swift
//  BledCar
//
//  Scanner natif QR / Code-barres pour valider les réservations.
//  Utilise AVFoundation – 100% natif, impossible dans un navigateur web.
//

#if os(iOS)
import SwiftUI
import AVFoundation

// MARK: - Vue principale Scanner

struct ScannerView: View {

    let onCodeScanned: (String) -> Void
    let onClose: () -> Void

    @State private var isFlashOn: Bool = false
    @State private var scanned: Bool = false
    @State private var scannedCode: String = ""
    @State private var showResult: Bool = false
    @StateObject private var camera = CameraPermissionChecker()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAuthorized {
                // Flux caméra
                QRCameraPreview(
                    isFlashOn: $isFlashOn,
                    onCodeScanned: { code in
                        guard !scanned else { return }
                        scanned = true
                        scannedCode = code
                        showResult = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                )
                .ignoresSafeArea()

                // Cadre de visée
                scanFrame

            } else if camera.isDenied {
                permissionDenied
            } else {
                ProgressView()
                    .tint(.white)
                    .onAppear { camera.requestAccess() }
            }

            // Barre du haut
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        isFlashOn.toggle()
                    } label: {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isFlashOn ? .bcGold : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                Spacer()
            }

            // Résultat après scan
            if showResult {
                scanResult
            }
        }
        .navigationTitle("Scanner")
        .navigationBarHidden(true)
        // Alerte résultat
        .alert("Code scanné", isPresented: $showResult) {
            Button("Valider la réservation") {
                onCodeScanned(scannedCode)
                onClose()
            }
            Button("Rescanner") {
                scanned = false
                scannedCode = ""
                showResult = false
            }
            Button("Annuler", role: .cancel) { onClose() }
        } message: {
            Text("Code : \(scannedCode)\n\nVoulez-vous valider cette réservation ?")
        }
    }

    // MARK: - Cadre de visée animé

    private var scanFrame: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.65
            let _ = (geo.size.width  - size) / 2
            let y = (geo.size.height - size) / 2

            ZStack {
                // Fond semi-opaque autour du cadre
                Color.black.opacity(0.50)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .frame(width: size, height: size)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Coins du cadre
                ScanCorners(size: size)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Instruction
                VStack(spacing: 12) {
                    Spacer().frame(height: y + size + 24)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.80))
                    Text("Pointez vers le code de réservation")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: 12)
            }
        }
    }

    // MARK: - Résultat (overlay)
    private var scanResult: some View { EmptyView() } // géré par .alert

    // MARK: - Permission refusée
    private var permissionDenied: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.white.opacity(0.50))
            Text("Accès caméra requis")
                .font(.title3.weight(.semibold)).foregroundColor(.white)
            Text("BledCar a besoin de la caméra pour scanner les codes de validation de réservation.")
                .font(.subheadline).foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.headline).foregroundColor(.bcAccent)
        }
    }
}

// MARK: - Coins du cadre

private struct ScanCorners: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                CornerLine(index: i, size: size)
            }
        }
    }
}

private struct CornerLine: View {
    let index: Int
    let size: CGFloat
    var body: some View {
        let len: CGFloat = 28
        let thick: CGFloat = 4
        let half = size / 2
        let xSign: CGFloat = (index % 2 == 0) ? -1 : 1
        let ySign: CGFloat = (index < 2)       ? -1 : 1
        return ZStack {
            Rectangle().fill(Color.bcAccent)
                .frame(width: len, height: thick)
                .offset(x: xSign * (half - len / 2), y: ySign * half)
            Rectangle().fill(Color.bcAccent)
                .frame(width: thick, height: len)
                .offset(x: xSign * half, y: ySign * (half - len / 2))
        }
    }
}

// MARK: - Preview caméra (UIViewRepresentable)

struct QRCameraPreview: UIViewRepresentable {

    @Binding var isFlashOn: Bool
    let onCodeScanned: (String) -> Void

    func makeUIView(context: Context) -> CameraView {
        let view = CameraView()
        view.onCodeScanned = onCodeScanned
        view.setup()
        return view
    }

    func updateUIView(_ uiView: CameraView, context: Context) {
        uiView.setFlash(on: isFlashOn)
    }
}

final class CameraView: UIView, AVCaptureMetadataOutputObjectsDelegate {

    var onCodeScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let output = AVCaptureMetadataOutput()

    func setup() {
        backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        if session.canAddInput(input)  { session.addInput(input) }
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr, .code128, .code39, .ean13, .ean8, .pdf417, .aztec]
        }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func setFlash(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        session.stopRunning()
        onCodeScanned?(value)
    }
}

// MARK: - Vérification permission caméra

@MainActor
final class CameraPermissionChecker: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isDenied: Bool = false

    init() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: isAuthorized = true
        case .denied, .restricted: isDenied = true
        default: break
        }
    }

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                self.isAuthorized = granted
                self.isDenied = !granted
            }
        }
    }
}
#endif
