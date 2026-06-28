import 'dart:math';
import 'package:flutter/animation.dart';

class AutoZoomController {
  final void Function(double) onZoomChanged;
  final TickerProvider vsync;
  final double threshold;
  final double maxDigitalZoom;
  final Duration timeout;

  late final AnimationController _animController;
  Animation<double>? _zoomAnimation;
  
  double _currentZoom = 1.0;
  bool _isPaused = false;
  DateTime? _maxZoomStartTime;

  AutoZoomController({
    required this.onZoomChanged,
    required this.vsync,
    this.threshold = 0.20,
    this.maxDigitalZoom = 10.0,
    this.timeout = const Duration(seconds: 3),
  }) {
    _animController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
    _animController.addListener(() {
      if (_zoomAnimation != null && !_isPaused) {
        _currentZoom = _zoomAnimation!.value;
        onZoomChanged(_currentZoom);
        
        // Track timeout at max zoom
        if (_currentZoom >= maxDigitalZoom - 0.1) {
          _maxZoomStartTime ??= DateTime.now();
          if (DateTime.now().difference(_maxZoomStartTime!) > timeout) {
            resetZoom();
          }
        } else {
          _maxZoomStartTime = null;
        }
      }
    });
  }

  void processDetection(double boundingBoxRatio, double confidence) {
    if (_isPaused || _animController.isAnimating) return;

    if (boundingBoxRatio < threshold && boundingBoxRatio > 0.005) {
      double targetZoom = sqrt(0.25) / sqrt(boundingBoxRatio);
      
      // Confidence adjustment
      if (confidence < 0.5) {
        targetZoom = _currentZoom + (targetZoom - _currentZoom) / 2;
      }
      
      targetZoom = targetZoom.clamp(1.0, 3.0); 
      // Cap at 3.0 internally for auto-zoom smoothness per algorithm,
      // but if maxDigitalZoom is less than 3.0, cap it there
      if (targetZoom > maxDigitalZoom) {
        targetZoom = maxDigitalZoom;
      }

      // Only animate if the difference is significant
      if ((targetZoom - _currentZoom).abs() > 0.1) {
        _zoomAnimation = Tween<double>(begin: _currentZoom, end: targetZoom).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOut),
        );
        _animController.forward(from: 0.0);
      }
    }
  }

  void pause() {
    _isPaused = true;
    _animController.stop();
  }

  void resume() {
    _isPaused = false;
  }
  
  void setManualZoom(double zoom) {
    _currentZoom = zoom.clamp(1.0, maxDigitalZoom);
    onZoomChanged(_currentZoom);
    if (_currentZoom < maxDigitalZoom - 0.1) {
      _maxZoomStartTime = null;
    }
  }

  void resetZoom() {
    _animController.stop();
    _currentZoom = 1.0;
    _maxZoomStartTime = null;
    onZoomChanged(_currentZoom);
  }

  void dispose() {
    _animController.dispose();
  }
}
