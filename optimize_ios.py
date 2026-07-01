import re

with open('qrpay_sdk_ios/ios/Classes/CameraPipeline.swift', 'r') as f:
    content = f.read()

# 1. Preset & Video settings
old_config = """                self.captureSession.beginConfiguration()
                if self.captureSession.canAddInput(deviceInput) {
                    self.captureSession.addInput(deviceInput)
                }
                
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true"""
new_config = """                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .hd1280x720
                if self.captureSession.canAddInput(deviceInput) {
                    self.captureSession.addInput(deviceInput)
                }
                
                self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true"""
content = content.replace(old_config, new_config)

# 2. Add Pre-warm Vision
old_prewarm = """self.isPreWarmed = true
                os_log("[Init] Pre-warm done in %f ms", log: .default, type: .debug, (CACurrentMediaTime() - startTime) * 1000)"""
new_prewarm = """// Pre-warm Vision
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
                os_log("[Init] Pre-warm done in %f ms", log: .default, type: .debug, (CACurrentMediaTime() - startTime) * 1000)"""
content = content.replace(old_prewarm, new_prewarm)

# add createDummyPixelBuffer() at the end
dummy_buffer_func = """
    private func createDummyPixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 1, 1, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &pixelBuffer)
        return pixelBuffer
    }
}"""
content = re.sub(r"\}\s*$", dummy_buffer_func, content)

# 3. Add Semaphore processing lock
content = content.replace("private var isPreWarmed = false", "private var isPreWarmed = false\n    private let processingSemaphore = DispatchSemaphore(value: 1)")

# 4. Modify captureOutput
old_capture = """func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()"""
new_capture = """func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if processingSemaphore.wait(timeout: .now()) == .timedOut {
            return
        }
        defer { processingSemaphore.signal() }
        
        let now = CACurrentMediaTime()"""
content = content.replace(old_capture, new_capture)

# 5. Vision Request Configuration
old_request = """        request.symbologies = [.qr]
        
        do {"""
new_request = """        request.symbologies = [.qr]
        request.usesCPUOnly = false
        if #available(iOS 14.3, *) {
            request.revision = VNDetectBarcodesRequestRevision3
        }
        
        do {"""
content = content.replace(old_request, new_request)


with open('qrpay_sdk_ios/ios/Classes/CameraPipeline.swift', 'w') as f:
    f.write(content)

