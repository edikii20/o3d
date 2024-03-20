import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../interfaces/o3d_controller_interface.dart';

class O3dImp implements O3DControllerInterface {
  final WebViewController? webViewController;
  final String id;

  O3dImp({
    this.webViewController,
    required this.id,
  });

  @override
  void cameraOrbit(double theta, double phi, double radius) {
    webViewController?.runJavascript('''(() => {
        cameraOrbit$id($theta, $phi, $radius); 
      })();
    ''');
  }

  @override
  void cameraTarget(double x, double y, double z) {
    webViewController?.runJavascript('''(() => {
        cameraTarget$id($x, $y, $z); 
      })();
    ''');
  }

  @override
  void customJsCode(String code) {
    webViewController?.runJavascript('''(() => {
        customEvaluate$id('$code'); 
      })();
    ''');
  }

  @override
  ValueChanged<Object>? logger;

  @override
  set animationName(String? name) {
    webViewController?.runJavascript('''(() => {
        animationName$id('$name'); 
      })();
    ''');
  }

  @override
  set autoRotate(bool? set) {
    webViewController?.runJavascript('''(() => {
        autoRotate$id($set); 
      })();
    ''');
  }

  @override
  set autoPlay(bool? set) {
    webViewController?.runJavascript('''(() => {
        autoPlay$id($set); 
      })();
    ''');
  }

  @override
  set cameraControls(bool? set) {
    webViewController?.runJavascript('''(() => {
        cameraControls$id($set); 
      })();
    ''');
  }

  @override
  set variantName(String? set) {
    webViewController?.runJavascript('''(() => {
        variantName$id('$set'); 
      })();
    ''');
  }

  @override
  Future<List<String>> availableAnimations() async {
    final res = await webViewController?.runJavascriptReturningResult(
        'document.querySelector(\'#$id\').availableAnimations');
    return jsonDecode(res as String).cast<String>();
  }

  @override
  void pause() {
    webViewController?.runJavascript('''(() => {
        pause$id(); 
      })();
''');
  }

  @override
  void play({int? repetitions}) {
    webViewController?.runJavascript('''(() => {
        play$id({repetitions: $repetitions}); 
      })();
''');
  }
}
