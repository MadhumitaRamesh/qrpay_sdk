import re

with open('qrpay_sdk_android/android/src/main/kotlin/com/example/qrpay_sdk/CameraPipeline.kt', 'r') as f:
    content = f.read()

# 1. BarcodeScanner client config & Prewarm
old_scanner = "scanner = BarcodeScanning.getClient()"
new_scanner = """val options = com.google.mlkit.vision.barcode.BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_QR_CODE)
                    .build()
                scanner = BarcodeScanning.getClient(options)
                
                val blankBitmap = android.graphics.Bitmap.createBitmap(1, 1, android.graphics.Bitmap.Config.ARGB_8888)
                val dummyImage = InputImage.fromBitmap(blankBitmap, 0)
                val warmupStart = System.currentTimeMillis()
                scanner?.process(dummyImage)?.addOnCompleteListener {
                    Log.d(TAG, "[QRPaySDK_METRIC] MLKIT_WARMUP_MS: ${System.currentTimeMillis() - warmupStart}")
                }?.await()"""
content = content.replace(old_scanner, new_scanner)

# 2. ImageAnalysis config
old_image = """imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()"""
new_image = """imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                    .setTargetResolution(android.util.Size(1280, 720))
                    .setTargetRotation(android.view.Surface.ROTATION_0)
                    .build()"""
content = content.replace(old_image, new_image)

# 3. Zoom reset
old_bind = """camera = cameraProvider?.bindToLifecycle(
                lifecycleOwner!!,
                cameraSelector,
                preview,
                imageAnalysis
            )"""
new_bind = old_bind + "\n            camera?.cameraControl?.setZoomRatio(1.0f)"
content = content.replace(old_bind, new_bind)

# 4. Processing lock and timing metrics
old_process = """@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun processImageProxy(imageProxy: ImageProxy) {"""
new_process = """private val isProcessing = java.util.concurrent.atomic.AtomicBoolean(false)

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun processImageProxy(imageProxy: ImageProxy) {
        if (!isProcessing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }
        val arrivalTime = System.currentTimeMillis()"""
content = content.replace(old_process, new_process)

# Update the media image block
content = re.sub(
r"val mediaImage = imageProxy\.image\n\s*if \(mediaImage != null && scanner != null\) \{",
r"""val mediaImage = imageProxy.image
        if (mediaImage != null && scanner != null) {
            val frameToMlkit = System.currentTimeMillis() - arrivalTime
            Log.d(TAG, "[QRPaySDK_METRIC] FRAME_TO_MLKIT_MS: $frameToMlkit")""", content)

content = re.sub(
r"val image = InputImage\.fromMediaImage\(mediaImage, imageProxy\.imageInfo\.rotationDegrees\)\n\s*scanner\?\.process\(image\)",
r"""val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            val inferenceStart = System.currentTimeMillis()
            scanner?.process(image)""", content)

content = re.sub(
r"\.addOnSuccessListener \{ barcodes ->",
r""".addOnSuccessListener { barcodes ->
                    val inferenceMs = System.currentTimeMillis() - inferenceStart
                    Log.d(TAG, "[QRPaySDK_METRIC] MLKIT_INFERENCE_MS: $inferenceMs")""", content)
                    
content = re.sub(
r"Log\.d\(TAG, \"\[QRPaySDK_METRIC\] DECODE_MS: \$decodeMs\"\)\n\s*eventSink\(\)\?\.success\(scanMap\)",
r"""val totalEmit = System.currentTimeMillis() - arrivalTime
                            Log.d(TAG, "[QRPaySDK_METRIC] TOTAL_DETECT_TO_EMIT_MS: $totalEmit")
                            eventSink()?.success(scanMap)""", content)

content = re.sub(
r"\.addOnCompleteListener \{\n\s*imageProxy\.close\(\)\n\s*\}",
r""".addOnCompleteListener {
                    imageProxy.close()
                    isProcessing.set(false)
                }""", content)

content = re.sub(
r"\} else \{\n\s*imageProxy\.close\(\)\n\s*\}",
r"""} else {
            imageProxy.close()
            isProcessing.set(false)
        }""", content)


with open('qrpay_sdk_android/android/src/main/kotlin/com/example/qrpay_sdk/CameraPipeline.kt', 'w') as f:
    f.write(content)

