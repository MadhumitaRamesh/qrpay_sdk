package com.example.qrpay_sdk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler

class QrpaySdkPlugin: FlutterPlugin, MethodCallHandler, StreamHandler {
  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private var eventSink: EventSink? = null
  private var cameraPipeline: CameraPipeline? = null
  private lateinit var context: Context
  private lateinit var pluginBinding: FlutterPlugin.FlutterPluginBinding

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    pluginBinding = flutterPluginBinding
    context = flutterPluginBinding.applicationContext
    
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "qrpay_sdk/control")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "qrpay_sdk/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> {
        cameraPipeline = CameraPipeline(context, pluginBinding.textureRegistry) { eventSink }
        cameraPipeline?.initializeAsync()
        result.success(null)
      }
      "dispose" -> {
        cameraPipeline?.shutdownPipeline()
        cameraPipeline = null
        result.success(null)
      }
      "stopScanning" -> {
        cameraPipeline?.shutdownPipeline()
        result.success(null)
      }
      "setTorch" -> {
        val on = call.argument<Boolean>("on") ?: false
        cameraPipeline?.setTorch(on)
        result.success(null)
      }
      "setZoom" -> {
        val ratio = call.argument<Double>("ratio") ?: 1.0
        cameraPipeline?.setZoom(ratio)
        result.success(null)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  override fun onListen(arguments: Any?, events: EventSink?) {
    eventSink = events
    
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
        eventSink?.success(mapOf("type" to "error", "code" to "permission-denied", "description" to "Camera permission not granted"))
        return
    }

    val textureId = cameraPipeline?.startScanning()
    if (textureId != null && textureId != -1L) {
        eventSink?.success(mapOf("type" to "texture", "id" to textureId))
    } else {
        eventSink?.success(mapOf("type" to "error", "code" to "camera-unavailable", "description" to "Failed to start camera"))
    }
  }

  override fun onCancel(arguments: Any?) {
    cameraPipeline?.shutdownPipeline()
    eventSink = null
  }
}
