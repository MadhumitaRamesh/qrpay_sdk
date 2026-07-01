import AVFoundation
import Vision
import Flutter
import os.log

class CameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let tag = "QRPaySDK"
    
    private let eventSink: () -> FlutterEventSink?
    
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sequenceRequestHandler = VNSequenceRequestHandler()
    private var isPreWarmed = false
    private let processingSemaphore = DispatchSemaphore(value: 1)
    
    private var lastDetectionTime: TimeInterval = 0
    private var frameCount = 0
    private var recoveryRetries = 0
    
    private let backgroundQueue = DispatchQueue(label: "com.qrpay.sdk.camera", qos: .userInteractive)
    
    init(eventSink: @escaping () -> FlutterEventSink?) {
        self.eventSink = eventSink
        super.init()
        setupThermalMonitoring()
        setupInterruptionMonitoring()
    }
    
    func initializeAsync() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            let startTime = CACurrentMediaTime()
            os_log("[Init] Starting pre-warm on background thread", log: .default, type: .debug)
            
            do {
                guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    throw NSError(domain: "CameraPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "No back camera available"])
                }
                
                let deviceInput = try AVCaptureDeviceInput(device: videoDevice)
                self.videoDeviceInput = deviceInput
                
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .hd1280x720
                if self.captureSession.canAddInput(deviceInput) {
                    self.captureSession.addInput(deviceInput)
                }
                
                self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.backgroundQueue)
                if self.captureSession.canAddOutput(self.videoDataOutput) {
                    self.captureSession.addOutput(self.videoDataOutput)
                }
                self.captureSession.commitConfiguration()
                
                // Pre-warm Vision
                let dummyPixelBuffer = self.createDummyPixelBuffer()
                if let buffer = dummyPixelBuffer {
                    let request = VNDetectBarcodesRequest()
                    request.symbologies = [.qr]
                    request.usesCPUOnly = false
                    if #available(iOS 14.3, *) {
                        request.revision = VNDetectBarcodesRequestRevision3
                    }
                    try? self.sequenceRequestHandler.perform([request], on: buffer)
                }
                os_log("[QRPaySDK_METRIC] MLKIT_WARMUP_MS: %f", log: .default, type: .debug, (CACurrentMediaTime() - startTime) * 1000)
                
                self.isPreWarmed = true
                os_log("[Init] Pre-warm done in %f ms", log: .default, type: .debug, (CACurrentMediaTime() - startTime) * 1000)
                
                DispatchQueue.main.async {
                    self.eventSink()?(["type": "lifecycle", "event": "camera-ready"])
                }
            } catch {
                os_log("[Init] Pre-warm failed: %@", log: .default, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    self.eventSink()?(["type": "error", "code": "camera-unavailable", "description": error.localizedDescription])
                }
            }
        }
    }
    
    func startScanning() -> Int64 {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authStatus == .denied || authStatus == .restricted {
            DispatchQueue.main.async {
                self.eventSink()?(["type": "lifecycle", "event": "permission-revoked"])
            }
            return -1
        }
        
        let startTime = CACurrentMediaTime()
        os_log("[Start] startScanning invoked", log: .default, type: .debug)
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            self.recoveryRetries = 0
            DispatchQueue.main.async {
                self.eventSink()?(["type": "lifecycle", "event": "started"])
            }
            os_log("[Start] Camera started in %f ms", log: .default, type: .debug, (CACurrentMediaTime() - startTime) * 1000)
        }
        
        // Return a dummy texture ID since iOS doesn't use FlutterTexture for simple AVFoundation overlays yet (handled via PlatformView usually, or just assuming 0 for now as stub texture)
        return 0 
    }
    
    func shutdownPipeline() {
        let t0 = CACurrentMediaTime()
        os_log("[Shutdown] step 0: initiated", log: .default, type: .debug)
        
        // step 1: freeze input
        videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
        let t1 = CACurrentMediaTime()
        os_log("[Shutdown] step 1: freeze input - %f ms", log: .default, type: .debug, (t1 - t0) * 1000)
        
        // step 2: stop capture
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
            let t2 = CACurrentMediaTime()
            os_log("[Shutdown] step 2: stop capture - %f ms", log: .default, type: .debug, (t2 - t1) * 1000)
            
            // step 3: reset hardware
            if let device = self.videoDeviceInput?.device {
                do {
                    try device.lockForConfiguration()
                    if device.hasTorch {
                        device.torchMode = .off
                    }
                    device.videoZoomFactor = 1.0
                    device.unlockForConfiguration()
                } catch {
                    os_log("Failed to reset hardware: %@", log: .default, type: .error, error.localizedDescription)
                }
            }
            let t3 = CACurrentMediaTime()
            os_log("[Shutdown] step 3: reset hardware - %f ms", log: .default, type: .debug, (t3 - t2) * 1000)
            
            DispatchQueue.main.async {
                // step 4: release location
                self.eventSink()?(["type": "releaseLocation"])
                let t4 = CACurrentMediaTime()
                os_log("[Shutdown] step 4: release location - %f ms", log: .default, type: .debug, (t4 - t3) * 1000)
                
                // step 5: clear state
                // Nothing specific to clear for Vision buffer beyond the sequenceRequestHandler, which resets naturally
                let t5 = CACurrentMediaTime()
                os_log("[Shutdown] step 5: clear state - %f ms", log: .default, type: .debug, (t5 - t4) * 1000)
                
                // step 6: scan-complete
                self.eventSink()?(["type": "lifecycle", "event": "scan-complete"])
                os_log("[Shutdown] step 6: scan-complete event emitted. Total time: %f ms", log: .default, type: .debug, (CACurrentMediaTime() - t0) * 1000)
            }
        }
    }
    
    func setTorch(on: Bool) {
        backgroundQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            if device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = on ? .on : .off
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self?.eventSink()?(["type": "torchState", "state": on])
                    }
                } catch {
                    os_log("Failed to set torch: %@", log: .default, type: .error, error.localizedDescription)
                }
            } else {
                DispatchQueue.main.async {
                    self?.eventSink()?(["type": "error", "code": "torch-unavailable", "description": "No flash unit available"])
                }
            }
        }
    }
    
    func setZoom(ratio: Double) {
        backgroundQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let zoomRatio = max(device.minAvailableVideoZoomFactor, min(CGFloat(ratio), device.maxAvailableVideoZoomFactor))
                device.videoZoomFactor = zoomRatio
                device.unlockForConfiguration()
            } catch {
                os_log("Failed to set zoom: %@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if processingSemaphore.wait(timeout: .now()) == .timedOut {
            return
        }
        defer { processingSemaphore.signal() }
        
        let now = CACurrentMediaTime()
        let timeSinceLastDetection = now - lastDetectionTime
        
        // Adaptive FPS: 30fps active, ~10fps idle
        if timeSinceLastDetection > 2.0 {
            frameCount += 1
            if frameCount % 3 != 0 {
                return
            }
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                os_log("Barcode processing failed: %@", log: .default, type: .error, error.localizedDescription)
                return
            }
            
            guard let results = request.results as? [VNBarcodeObservation], let barcode = results.first else { return }
            
            self.lastDetectionTime = CACurrentMediaTime()
            let rawString = barcode.payloadStringValue ?? ""
            
            // Vision bounding box is normalized [0,1], origin at bottom-left
            let boxArea = barcode.boundingBox.width * barcode.boundingBox.height
            let ratio = Double(boxArea) // area ratio is directly the box area since frame is 1.0 x 1.0
            
            let scanMap: [String: Any] = [
                "type": "result",
                "rawString": rawString,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "confidence": 1.0,
                "boundingRatio": ratio
            ]
            
            DispatchQueue.main.async {
                self.eventSink()?(scanMap)
            }
            
            self.shutdownPipeline()
        }
        
        request.symbologies = [.qr]
        request.usesCPUOnly = false
        if #available(iOS 14.3, *) {
            request.revision = VNDetectBarcodesRequestRevision3
        }
        
        do {
            try sequenceRequestHandler.perform([request], on: pixelBuffer)
        } catch {
            os_log("Vision request failed: %@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            let stateStr: String
            switch ProcessInfo.processInfo.thermalState {
            case .nominal: stateStr = "normal"
            case .fair: stateStr = "fair"
            case .serious: stateStr = "serious"
            case .critical: stateStr = "critical"
            @unknown default: stateStr = "normal"
            }
            self?.eventSink()?(["type": "thermalState", "state": stateStr])
        }
    }
    
    private func setupInterruptionMonitoring() {
        NotificationCenter.default.addObserver(forName: .AVCaptureSessionWasInterrupted, object: nil, queue: .main) { [weak self] _ in
            self?.eventSink()?(["type": "lifecycle", "event": "camera-interrupted"])
            self?.attemptRecovery()
        }
    }
    
    private func attemptRecovery() {
        if recoveryRetries < 3 {
            recoveryRetries += 1
            os_log("[Recovery] Attempt %d", log: .default, type: .debug, recoveryRetries)
            backgroundQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            }
        } else {
            eventSink()?(["type": "lifecycle", "event": "camera-unrecoverable"])
            shutdownPipeline()
        }
    }

    private func createDummyPixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 1, 1, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &pixelBuffer)
        return pixelBuffer
    }
}