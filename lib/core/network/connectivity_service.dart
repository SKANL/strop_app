import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {

  ConnectivityService(this._connectivity) {
    _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      _controller.add(isConnected);
    });
  }
  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}
