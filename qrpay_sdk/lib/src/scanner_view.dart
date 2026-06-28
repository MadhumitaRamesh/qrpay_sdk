import 'dart:async';
import 'package:flutter/material.dart';
import 'qrpay.dart';
import 'config/qrpay_config.dart';
import 'model/scan_result.dart';
import 'model/qrpay_error.dart';
import 'overlay/positioning_overlay_painter.dart';
import 'state/auto_zoom_controller.dart';

class ScannerView extends StatefulWidget {
  final QRPayConfig config;
  final void Function(ScanResult)? onScan;
  final void Function(QRPayError)? onError;
  final VoidCallback? onScanComplete;

  const ScannerView({
    Key? key,
    required this.config,
    this.onScan,
    this.onError,
    this.onScanComplete,
  }) : super(key: key);

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> with SingleTickerProviderStateMixin {
  late AutoZoomController _autoZoomController;
  StreamSubscription? _scanSubscription;
  int? _textureId;
  double _baseScale = 1.0;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _autoZoomController = AutoZoomController(
      vsync: this,
      threshold: widget.config.autoZoomThreshold,
      maxDigitalZoom: widget.config.maxDigitalZoom,
      timeout: widget.config.autoZoomTimeout,
      onZoomChanged: (zoom) {
        QRPay.setZoom(zoom);
      },
    );
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      await QRPay.initialize(widget.config);
      _scanSubscription = QRPay.startScanning().listen(_handleScanEvent);
    } catch (e) {
      if (widget.onError != null) {
        widget.onError!(ConfigInvalid(description: e.toString()));
      }
    }
  }

  void _handleScanEvent(ScanEvent event) {
    if (event is ScanEventTexture) {
      setState(() {
        _textureId = event.textureId;
      });
    } else if (event is ScanEventResult) {
      if (widget.onScan != null) widget.onScan!(event.result);
      if (widget.config.autoZoomEnabled) {
        _autoZoomController.processDetection(event.boundingRatio, event.result.confidence);
      }
    } else if (event is ScanEventError) {
      if (widget.onError != null) widget.onError!(event.error);
    } else if (event is ScanEventLifecycle) {
      if (event.event == LifecycleEvent.stopped) {
        if (widget.onScanComplete != null) widget.onScanComplete!();
        _autoZoomController.resetZoom();
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _autoZoomController.dispose();
    QRPay.dispose();
    super.dispose();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _autoZoomController.pause();
    _baseScale = _currentScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    _currentScale = (_baseScale * details.scale).clamp(1.0, widget.config.maxDigitalZoom);
    _autoZoomController.setManualZoom(_currentScale);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _autoZoomController.resume();
  }

  @override
  Widget build(BuildContext context) {
    if (_textureId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Texture(textureId: _textureId!),
          CustomPaint(
            painter: PositioningOverlayPainter(style: widget.config.overlayStyle),
          ),
        ],
      ),
    );
  }
}
