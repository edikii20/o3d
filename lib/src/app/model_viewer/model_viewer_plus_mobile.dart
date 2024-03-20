import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show File, HttpServer, HttpStatus, InternetAddress, Platform;
import 'package:android_intent_plus/android_intent.dart' as android_content;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_android.dart' as android;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart'
    as ios;

import 'html_builder.dart';
import 'o3d_model_viewer.dart';

class ModelViewerState extends State<O3DModelViewer> {
  HttpServer? _proxy;
  WebViewController? _webViewController;
  late String _proxyURL;
  List<String> routesRequested = [];

  @override
  void initState() {
    super.initState();
    unawaited(
      _initProxy().then(
        (_) => _initController()
          ..catchError(
            (e) => widget.controller?.logger?.call('init control error: $e'),
          ),
      )..catchError(
          (e) => widget.controller?.logger?.call('init proxy error $e'),
        ),
    );
  }

  @override
  void dispose() {
    if (_proxy != null) {
      unawaited(_proxy!.close(force: true));
      _proxy = null;
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    if (_proxy == null || _webViewController == null) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading Model Viewer',
        ),
      );
    }
    return WebView(
      onWebViewCreated: (controller) {
        _webViewController = controller;
        debugPrint('INIT CONTROLLER !!!!');
        _initController();
      },
      // controller: _webViewController!,
      javascriptMode: JavascriptMode.unrestricted,
      backgroundColor: Colors.transparent,
      navigationDelegate: (navigation) async {
        debugPrint('ModelViewer wants to load: ${navigation.url}');
        if (Platform.isIOS && navigation.url == widget.iosSrc) {
          await launchUrl(
            Uri.parse(navigation.url.trimLeft()),
            mode: LaunchMode.inAppWebView,
          );
          return NavigationDecision.prevent;
        }
        if (!Platform.isAndroid) {
          return NavigationDecision.navigate;
        }
        if (!navigation.url.startsWith('intent://')) {
          return NavigationDecision.navigate;
        }
        try {
          // Original, just keep as a backup
          // See: https://developers.google.com/ar/develop/java/scene-viewer
          // final intent = android_content.AndroidIntent(
          //   action: "android.intent.action.VIEW", // Intent.ACTION_VIEW
          //   data: "https://arvr.google.com/scene-viewer/1.0",
          //   arguments: <String, dynamic>{
          //     'file': widget.src,
          //     'mode': 'ar_preferred',
          //   },
          //   package: "com.google.ar.core",
          //   flags: <int>[
          //     Flag.FLAG_ACTIVITY_NEW_TASK
          //   ], // Intent.FLAG_ACTIVITY_NEW_TASK,
          // );

          final String fileURL;
          if (['http', 'https'].contains(Uri.parse(widget.src).scheme)) {
            fileURL = widget.src;
          } else {
            fileURL = p.joinAll([_proxyURL, 'model']);
          }
          final intent = android_content.AndroidIntent(
            action: 'android.intent.action.VIEW',
            // Intent.ACTION_VIEW
            // See https://developers.google.com/ar/develop/scene-viewer#3d-or-ar
            // data should be something like "https://arvr.google.com/scene-viewer/1.0?file=https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Avocado/glTF/Avocado.gltf"
            data: Uri(
              scheme: 'https',
              host: 'arvr.google.com',
              path: '/scene-viewer/1.0',
              queryParameters: {
                'mode': 'ar_preferred',
                'file': fileURL,
              },
            ).toString(),
            // package changed to com.google.android.googlequicksearchbox
            // to support the widest possible range of devices
            package: 'com.google.android.googlequicksearchbox',
            arguments: <String, dynamic>{
              'browser_fallback_url':
                  'market://details?id=com.google.android.googlequicksearchbox',
            },
          );
          await intent.launch().onError((error, stackTrace) {
            debugPrint('ModelViewer Intent Error: $error');
          });
        } on Object catch (error) {
          debugPrint('ModelViewer failed to launch AR: $error');
        }
        return NavigationDecision.prevent;
      },
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }

  String _buildHTML(String htmlTemplate) {
    return HTMLBuilder.build(
      htmlTemplate: htmlTemplate,
      src: '/model',
      alt: widget.alt,
      poster: widget.poster,
      loading: widget.loading,
      reveal: widget.reveal,
      withCredentials: widget.withCredentials,
      // AR Attributes
      ar: widget.ar,
      arModes: widget.arModes,
      arScale: widget.arScale,
      arPlacement: widget.arPlacement,
      iosSrc: widget.iosSrc,
      xrEnvironment: widget.xrEnvironment,
      // Cameras Attributes
      cameraControls: widget.cameraControls,
      disablePan: widget.disablePan,
      disableTap: widget.disableTap,
      touchAction: widget.touchAction,
      disableZoom: widget.disableZoom,
      orbitSensitivity: widget.orbitSensitivity,
      autoRotate: widget.autoRotate,
      autoRotateDelay: widget.autoRotateDelay,
      rotationPerSecond: widget.rotationPerSecond,
      interactionPrompt: widget.interactionPrompt,
      interactionPromptStyle: widget.interactionPromptStyle,
      interactionPromptThreshold: widget.interactionPromptThreshold,
      cameraOrbit: widget.cameraOrbit,
      cameraTarget: widget.cameraTarget,
      fieldOfView: widget.fieldOfView,
      maxCameraOrbit: widget.maxCameraOrbit,
      minCameraOrbit: widget.minCameraOrbit,
      maxFieldOfView: widget.maxFieldOfView,
      minFieldOfView: widget.minFieldOfView,
      interpolationDecay: widget.interpolationDecay,
      // Lighting & Env Attributes
      skyboxImage: widget.skyboxImage,
      environmentImage: widget.environmentImage,
      exposure: widget.exposure,
      shadowIntensity: widget.shadowIntensity,
      shadowSoftness: widget.shadowSoftness,
      // Animation Attributes
      animationName: widget.animationName,
      animationCrossfadeDuration: widget.animationCrossfadeDuration,
      autoPlay: widget.autoPlay,
      // Materials & Scene Attributes
      variantName: widget.variantName,
      orientation: widget.orientation,
      scale: widget.scale,
      // CSS Styles
      backgroundColor: widget.backgroundColor,
      // Annotations CSS
      minHotspotOpacity: widget.minHotspotOpacity,
      maxHotspotOpacity: widget.maxHotspotOpacity,
      // Others
      innerModelViewerHtml: widget.innerModelViewerHtml,
      relatedCss: widget.relatedCss,
      relatedJs: widget.relatedJs,
      id: widget.id,
      debugLogging: widget.debugLogging,
    );
  }

  Future<void> _initController() async {
    widget.controller?.logger?.call("init config");

    // widget.javascriptChannels?.forEach((element) {
    //   _webViewController.addJavaScriptChannel(
    //     element.name,
    //     onMessageReceived: element.onMessageReceived,
    //   );
    // });

    debugPrint('ModelViewer initializing... <$_proxyURL>');
    // widget.onWebViewCreated?.call(webViewController);
    await _webViewController?.loadRequest(WebViewRequest(
        uri: Uri.parse(_proxyURL), method: WebViewRequestMethod.get));
    setState(() {});
    widget.controller?.logger?.call('initialized webViewController');
    // Future.delayed(const Duration(seconds: 5),() => _webViewController?.loadRequest(Uri.parse('${_proxyURL}model')));
  }

  Future<void> _initProxy() async {
    try {
      String src = widget.src;

      widget.controller?.logger?.call('init proxy start');

      final url = Uri.parse(src);
      _proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      widget.controller?.logger?.call('url is ${url.toString()}');

      setState(() {
        final host = _proxy!.address.address;
        final port = _proxy!.port;
        _proxyURL = 'http://$host:$port/';
      });
      _proxy!.listen((request) async {
        final response = request.response;
        // if(routesRequested.contains(request.uri.path)){
        //   return;
        // }

        // routesRequested.add(request.uri.path);

        widget.controller?.logger?.call('url is ${request.uri.path}');

        switch (request.uri.path) {
          case '/':
          case '/index.html':
            final htmlTemplate = await rootBundle
                .loadString('packages/o3d/assets/template.html');
            final html = utf8.encode(_buildHTML(htmlTemplate));

            widget.controller?.logger?.call(
                'html is not empty: ${html.isNotEmpty} and length is ${html.length.toString()}');

            response
              ..statusCode = HttpStatus.ok
              ..headers.add('Content-Type', 'text/html;charset=UTF-8')
              ..headers.add('Access-Control-Allow-Origin', '*')
              ..headers.add('Content-Length', html.length.toString())
              ..add(html);
            await response.close();
          case '/model-viewer.min.js':
            final code = await rootBundle
                .loadString('packages/o3d/assets/model-viewer.min.js');
            final data = utf8.encode(code);

            widget.controller?.logger?.call(
                'js is not empty: ${code.isNotEmpty} and length: ${data.length.toString()}');

            response
              ..statusCode = HttpStatus.ok
              ..headers
                  .add('Content-Type', 'application/javascript;charset=UTF-8')
              ..headers.add('Access-Control-Allow-Origin', '*')
              ..headers.add('Content-Length', data.length.toString())
              ..add(data);
            await response.close();
          case '/model':
            if (url.isAbsolute && !url.isScheme('file')) {
              await response.redirect(url);
            } else {
              final data = await (url.isScheme('file')
                  ? _readFile(url.path)
                  : _readAsset(url.path));
              if (data != null) {
                widget.controller?.logger?.call(
                    'data is not empty: ${data.isNotEmpty} and length is ${data.length}');

                response
                  ..statusCode = HttpStatus.ok
                  ..headers.add('Content-Type', 'application/octet-stream')
                  ..headers.add('Content-Length', data.lengthInBytes.toString())
                  ..headers.add('Access-Control-Allow-Origin', '*')
                  ..add(data);
              } else {
                widget.controller?.logger
                    ?.call('data is empty --------------------------------');
              }
              await response.close();
            }
          case '/favicon.ico':
            final text = utf8.encode("Resource '${request.uri}' not found");

            widget.controller?.logger?.call(
                'favicon is not empty: ${text.isNotEmpty} and length is ${text.length.toString()}');

            response
              ..statusCode = HttpStatus.notFound
              ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
              ..headers.add('Content-Length', text.length.toString())
              ..add(text);
            await response.close();
          default:
            if (request.uri.isAbsolute) {
              debugPrint('Redirect: ${request.uri}');
              await response.redirect(request.uri);
            } else if (request.uri.hasAbsolutePath) {
              // Some gltf models need other resources from the origin
              final pathSegments = [...url.pathSegments]..removeLast();
              final tryDestination = p.joinAll([
                url.origin,
                ...pathSegments,
                request.uri.path.replaceFirst('/', ''),
              ]);
              debugPrint('Try: $tryDestination');
              await response.redirect(Uri.parse(tryDestination));
            } else {
              debugPrint('404 with ${request.uri}');
              final text = utf8.encode("Resource '${request.uri}' not found");
              response
                ..statusCode = HttpStatus.notFound
                ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
                ..headers.add('Content-Length', text.length.toString())
                ..add(text);
              await response.close();
              break;
            }
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List?> _readAsset(String path) async {
    // final tempDir = await p_p.getTemporaryDirectory();
    // String tempPath = tempDir.path;
    //
    // final filePath = "$tempPath/$path";
    // print("filePathfilePath=$filePath");
    // final file = File(filePath);
    // if (file.existsSync()) {
    //   return file.readAsBytesSync();
    // } else {
    //   return null;
    // }
    /// 2
    try {
      final code = await rootBundle.load(path);

      return code.buffer.asUint8List();
    } catch (e) {
      widget.controller?.logger?.call('error in _readAsset: $e');
      return null;
    }
  }

  Future<Uint8List> _readFile(final String path) async {
    final file = File(path);

    widget.controller?.logger
        ?.call('_readFile data exist: ${file.existsSync()}');
    return file.readAsBytes();
  }
}
