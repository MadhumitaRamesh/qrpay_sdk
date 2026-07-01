package com.example.qrpay_sdk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

class PluginLifecycleOwner : LifecycleOwner {
    private val lifecycleRegistry = LifecycleRegistry(this)

    init {
        lifecycleRegistry.currentState = Lifecycle.State.INITIALIZED
    }

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    fun start() {
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
    }

    fun stop() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
    }
}

class CameraPipeline(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val eventSink: () -> EventChannel.EventSink?
) {
    companion object {
        const val TAG = "QRPaySDK"
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main + Job())
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    // Timing anchors for greppable log metrics
    private var initCallTime = 0L
    private var startScanCallTime = 0L
    private var firstFrameLogged = false
    private var detectionTime = 0L

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var scanner: BarcodeScanner? = null
    private var lifecycleOwner: PluginLifecycleOwner? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

    private var lastDetectionTime = 0L
    private var frameCount = 0
    private var recoveryRetries = 0

    var isPreWarmed = false
        private set

    fun initializeAsync() {
        // REQ-03.3: Record the wall-clock time at the point the Flutter method call arrives.
        initCallTime = System.currentTimeMillis()
        Log.d(TAG, "[Init] Starting pre-warm on background thread")

        // METRIC-1: Time from initialize() Flutter call to this function returning (i.e. Future<void>
        // completing on Dart side). The coroutine is launched but we return immediately, so the
        // Future completes before the coroutine body runs. Log INIT_COMPLETE_MS here.
        val initReturnTime = System.currentTimeMillis()
        Log.d(TAG, "[QRPaySDK_METRIC] INIT_COMPLETE_MS: ${initReturnTime - initCallTime}")

        coroutineScope.launch {
            try {
                cameraProvider = ProcessCameraProvider.getInstance(context).await()
                scanner = BarcodeScanning.getClient()

                preview = Preview.Builder().build()
                imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                setupThermalMonitoring()

                isPreWarmed = true

                withContext(Dispatchers.Main) {
                    // METRIC-2: Time from initialize() call to camera-ready event (actual pre-warm done).
                    val prewarmMs = System.currentTimeMillis() - initCallTime
                    Log.d(TAG, "[QRPaySDK_METRIC] PREWARM_COMPLETE_MS: $prewarmMs")
                    eventSink()?.success(mapOf("type" to "lifecycle", "event" to "camera-ready"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "[Init] Pre-warm failed", e)
                withContext(Dispatchers.Main) {
                    eventSink()?.success(mapOf("type" to "error", "code" to "camera-unavailable", "description" to e.message))
                }
            }
        }
    }

    private fun setupThermalMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.addThermalStatusListener { status ->
                val stateStr = when(status) {
                    PowerManager.THERMAL_STATUS_NONE, PowerManager.THERMAL_STATUS_LIGHT -> "normal"
                    PowerManager.THERMAL_STATUS_MODERATE -> "fair"
                    PowerManager.THERMAL_STATUS_SEVERE -> "serious"
                    PowerManager.THERMAL_STATUS_CRITICAL, PowerManager.THERMAL_STATUS_EMERGENCY, PowerManager.THERMAL_STATUS_SHUTDOWN -> "critical"
                    else -> "normal"
                }
                coroutineScope.launch(Dispatchers.Main) {
                    eventSink()?.success(mapOf("type" to "thermalState", "state" to stateStr))
                }
            }
        }
    }

    fun startScanning(): Long {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            eventSink()?.success(mapOf("type" to "lifecycle", "event" to "permission-revoked"))
            return -1
        }

        // REQ-04.3: Record start time for FIRST_FRAME_MS metric. Reset first-frame flag.
        startScanCallTime = System.currentTimeMillis()
        firstFrameLogged = false
        val startTime = startScanCallTime
        Log.d(TAG, "[Start] startScanning invoked")

        if (cameraProvider == null) {
            Log.e(TAG, "[Start] cameraProvider is null, wait for pre-warm")
            return -1
        }

        if (textureEntry == null) {
            textureEntry = textureRegistry.createSurfaceTexture()
        }
        val surfaceTexture = textureEntry!!.surfaceTexture()

        preview?.setSurfaceProvider { request ->
            surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = android.view.Surface(surfaceTexture)
            request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                surface.release()
            }
        }

        imageAnalysis?.setAnalyzer(analysisExecutor) { imageProxy ->
            processImageProxy(imageProxy)
        }

        if (lifecycleOwner == null) {
            lifecycleOwner = PluginLifecycleOwner()
        }
        lifecycleOwner?.start()

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        try {
            cameraProvider?.unbindAll()
            camera = cameraProvider?.bindToLifecycle(
                lifecycleOwner!!,
                cameraSelector,
                preview,
                imageAnalysis
            )
            
            camera?.cameraInfo?.cameraState?.observe(lifecycleOwner!!) { state ->
                if (state.error != null) {
                    handleCameraError(state.error!!)
                }
            }

            Log.d(TAG, "[Start] Camera bound to lifecycle in \${System.currentTimeMillis() - startTime}ms")
            recoveryRetries = 0
            eventSink()?.success(mapOf("type" to "lifecycle", "event" to "started"))
        } catch (e: Exception) {
            Log.e(TAG, "[Start] Use case binding failed", e)
            handleCameraError(null)
        }

        return textureEntry!!.id()
    }

    private fun handleCameraError(error: androidx.camera.core.CameraState.StateError?) {
        coroutineScope.launch(Dispatchers.Main) {
            eventSink()?.success(mapOf("type" to "lifecycle", "event" to "camera-interrupted"))
        }
        
        if (recoveryRetries < 3) {
            recoveryRetries++
            coroutineScope.launch {
                delay(500)
                Log.d(TAG, "[Recovery] Attempt \$recoveryRetries")
                startScanning()
            }
        } else {
            coroutineScope.launch(Dispatchers.Main) {
                eventSink()?.success(mapOf("type" to "lifecycle", "event" to "camera-unrecoverable"))
            }
            shutdownPipeline()
        }
    }

    @androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
    private fun processImageProxy(imageProxy: ImageProxy) {
        val now = System.currentTimeMillis()
        val timeSinceLastDetection = now - lastDetectionTime

        // Adaptive FPS
        if (timeSinceLastDetection > 2000L) {
            frameCount++
            if (frameCount % 3 != 0) {
                imageProxy.close()
                return
            }
        }

        val mediaImage = imageProxy.image
        if (mediaImage != null && scanner != null) {
            // METRIC-3: Log the first frame that actually reaches ML Kit processing.
            if (!firstFrameLogged) {
                firstFrameLogged = true
                val firstFrameMs = System.currentTimeMillis() - startScanCallTime
                Log.d(TAG, "[QRPaySDK_METRIC] FIRST_FRAME_MS: $firstFrameMs")
            }

            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            scanner?.process(image)
                ?.addOnSuccessListener { barcodes ->
                    if (barcodes.isNotEmpty()) {
                        // Record detection time for DECODE_MS and SHUTDOWN_TOTAL_MS metrics.
                        detectionTime = System.currentTimeMillis()
                        lastDetectionTime = detectionTime
                        val barcode = barcodes.first()
                        val rawString = barcode.rawValue ?: ""
                        
                        val frameArea = (imageProxy.width * imageProxy.height).toDouble()
                        val boxArea = if (barcode.boundingBox != null) {
                            (barcode.boundingBox!!.width() * barcode.boundingBox!!.height()).toDouble()
                        } else 0.0
                        
                        val ratio = if (frameArea > 0) boxArea / frameArea else 0.0
                        val confidence = 1.0

                        val scanMap = mapOf(
                            "type" to "result",
                            "rawString" to rawString,
                            "timestamp" to System.currentTimeMillis(),
                            "confidence" to confidence,
                            "boundingRatio" to ratio
                        )
                        
                        coroutineScope.launch(Dispatchers.Main) {
                            // METRIC-4: Time from QR detection to scan-result event emission.
                            val decodeMs = System.currentTimeMillis() - detectionTime
                            Log.d(TAG, "[QRPaySDK_METRIC] DECODE_MS: $decodeMs")
                            eventSink()?.success(scanMap)
                        }

                        shutdownPipeline()
                    }
                }
                ?.addOnFailureListener { e ->
                    if (e is com.google.mlkit.common.MlKitException && e.errorCode == com.google.mlkit.common.MlKitException.UNAVAILABLE) {
                        coroutineScope.launch(Dispatchers.Main) {
                            eventSink()?.success(mapOf("type" to "lifecycle", "event" to "ml-kit-downloading"))
                        }
                    } else {
                        Log.e(TAG, "Barcode processing failed", e)
                    }
                }
                ?.addOnCompleteListener {
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }

    fun shutdownPipeline() {
        val t0 = System.currentTimeMillis()
        Log.d(TAG, "[Shutdown] step 0: initiated")

        imageAnalysis?.clearAnalyzer()
        val t1 = System.currentTimeMillis()
        Log.d(TAG, "[Shutdown] step 1: freeze input - \${t1 - t0}ms")

        cameraProvider?.unbindAll()
        val t2 = System.currentTimeMillis()
        Log.d(TAG, "[Shutdown] step 2: stop capture - \${t2 - t1}ms")

        camera?.cameraControl?.enableTorch(false)
        camera?.cameraControl?.setZoomRatio(1.0f)
        val t3 = System.currentTimeMillis()
        Log.d(TAG, "[Shutdown] step 3: reset hardware - \${t3 - t2}ms")

        coroutineScope.launch(Dispatchers.Main) {
            eventSink()?.success(mapOf("type" to "releaseLocation"))
        }
        val t4 = System.currentTimeMillis()
        Log.d(TAG, "[Shutdown] step 4: release location - \${t4 - t3}ms")

        lifecycleOwner?.stop()
        lifecycleOwner = null
        textureEntry?.release()
        textureEntry = null
        val t5 = System.currentTimeMillis()
        Log.d(TAG, "[Shutdown] step 5: clear state - \${t5 - t4}ms")

        coroutineScope.launch(Dispatchers.Main) {
            eventSink()?.success(mapOf("type" to "lifecycle", "event" to "scan-complete"))
            val shutdownTotalMs = System.currentTimeMillis() - t0
            Log.d(TAG, "[Shutdown] step 6: scan-complete event emitted. Total time: ${shutdownTotalMs}ms")
            // METRIC-5: Summary line for the full shutdown sequence (scan-result -> scan-complete).
            Log.d(TAG, "[QRPaySDK_METRIC] SHUTDOWN_TOTAL_MS: $shutdownTotalMs")
        }
    }

    fun setTorch(on: Boolean) {
        if (camera?.cameraInfo?.hasFlashUnit() == true) {
            camera?.cameraControl?.enableTorch(on)?.addListener({
                coroutineScope.launch(Dispatchers.Main) {
                    eventSink()?.success(mapOf("type" to "torchState", "state" to on))
                }
            }, ContextCompat.getMainExecutor(context))
        } else {
            coroutineScope.launch(Dispatchers.Main) {
                eventSink()?.success(mapOf("type" to "error", "code" to "torch-unavailable", "description" to "No flash unit available"))
            }
        }
    }

    fun setZoom(ratio: Double) {
        camera?.cameraControl?.setZoomRatio(ratio.toFloat())
    }
}
