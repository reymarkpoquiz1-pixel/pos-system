import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  ConnectivityService._init();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isFirstCheck = true;
  
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(true);

  void initialize() {
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      bool isConnected = results.any((result) => result != ConnectivityResult.none);
      isConnectedNotifier.value = isConnected;
      
      debugPrint("Connectivity Changed: $results (Connected: $isConnected)");

      if (isConnected) {
        // Iwasan ang pag-sync agad sa unang load kung hindi naman kailangan, 
        // pero sa mga susunod na reconnections, trigger automatic sync.
        if (!_isFirstCheck) {
          SyncService.syncOfflineSales(null);
        }
        _isFirstCheck = false;
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<bool> checkConnection() async {
    final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
