import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kino Driburg',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Kino Driburg Programm'),
    );
  }
}

// define global variables
late WebViewController controllerGlobal;
const String programURL =
    "https://www.kinoheld.de/kino-bad-driburg/kino-bad-driburg/shows/movies?mode=widget&layout=movies&rb=1&hideTitle=1&floatingCart=1";
bool isLoading = false;

Future<bool> _handleBack(context) async {
  var status = await controllerGlobal.canGoBack();
  if (status) {
    controllerGlobal.goBack();
    return false;
  } else {
    return false;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

void _launchURL(String url) async {
  if (url.startsWith("tel:0")) {
    url = url.replaceFirst("0", "+49");
  }
  await launch(url);
  //await canLaunch(url) ? await launch(url) : throw 'Could not launch';
}

class _MyHomePageState extends State<MyHomePage> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  // define private variables
  int _loadingProgress = 0;
  final _storage = const FlutterSecureStorage();
  String _cookieList = "";

  @override
  initState() {
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    isLoading = true;
    _loadingProgress = 0;
    super.initState();
  }

  void _loadProgram() async {
    if (await controllerGlobal.currentUrl() != programURL) {
      controllerGlobal.loadUrl(programURL);
    }
  }

  void _loadCookies() async {
    if (await _storage.read(key: "cookieList") != null) {
      _cookieList = _storage.read(key: "cookieList").toString();

      controllerGlobal.evaluateJavascript("document.cookie = " + _cookieList);
    }
  }

  void _saveCookies() async {
    if (_cookieList.isNotEmpty) {
      await _storage.write(key: "cookieList", value: _cookieList);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () => _handleBack(context),
        child: SafeArea(
            top: true,
            child: Scaffold(
                appBar: AppBar(
                  title: _loadingProgress != 100
                      ? InkWell(
                          onTap: () {
                            _loadProgram();
                          },
                          child: Text(widget.title +
                              " (" +
                              _loadingProgress.toString() +
                              "%)"),
                        )
                      : InkWell(
                          onTap: () {
                            _loadProgram();
                          },
                          child: Text(widget.title),
                        ),
                  actions: <Widget>[
                    SampleMenu(_controller.future),
                  ],
                ),
                body: Stack(children: <Widget>[
                  Builder(builder: (BuildContext context) {
                    return WebView(
                      initialUrl: programURL,
                      javascriptMode: JavascriptMode.unrestricted,
                      onWebViewCreated: (WebViewController webViewController) {
                        _controller.complete(webViewController);
                        controllerGlobal = webViewController;
                        _loadCookies();
                        //controllerGlobal.evaluateJavascript(
                        //    "var now = new Date();now.setTime(now.getTime() + (120 * 60 * 1000));document.cookie = \"KHCONSENT=deny; expires=\" + now.toUTCString() + \"; domain=www.kinoheld.de; path=/\";");
                      },
                      navigationDelegate: (NavigationRequest request) {
                        if (request.url.startsWith('tel:') ||
                            request.url.startsWith("mailto:") ||
                            request.url
                                .startsWith("https://www.instagram.com/") ||
                            request.url
                                .startsWith("https://www.facebook.com/")) {
                          _launchURL(request.url);
                          return NavigationDecision.prevent;
                        }
                        return NavigationDecision.navigate;
                      },
                      onProgress: (int progress) {
                        setState(() {
                          _loadingProgress = progress;
                        });
                      },
                      onPageStarted: (String url) {
                        setState(() {
                          isLoading = true;
                        });
                        _saveCookies();
                      },
                      onPageFinished: (String url) {
                        setState(() {
                          isLoading = false;
                        });
                        // controllerGlobal.evaluateJavascript(
                        //     "document.getElementsByClassName(\"nav-drawer absolute\")[0].remove();document.getElementsByClassName(\"bottom-center _brlbs-block-content\").remove();");
                      },
                      gestureNavigationEnabled: true,
                    );
                  }),
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Container(),
                ]))));
  }
}

enum MenuOptions { showDev, quiz, prices, mainPage, programm }

class SampleMenu extends StatelessWidget {
  SampleMenu(this.controller);

  final Future<WebViewController> controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: controller,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> controller) {
        return PopupMenuButton<MenuOptions>(
          onSelected: (MenuOptions value) {
            switch (value) {
              case MenuOptions.showDev:
                _onShowDev(context);
                break;
              case MenuOptions.quiz:
                _onShowQuiz(controller.data, context);
                break;
              case MenuOptions.prices:
                _onShowPrices(controller.data, context);
                break;
              case MenuOptions.mainPage:
                _onShowMainPage(controller.data, context);
                break;
              case MenuOptions.programm:
                _onShowProgramm(controller.data, context);
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuItem<MenuOptions>>[
            PopupMenuItem<MenuOptions>(
              value: MenuOptions.programm,
              child: const Text('Programm'),
              enabled: controller.hasData,
            ),
            PopupMenuItem<MenuOptions>(
              value: MenuOptions.mainPage,
              child: const Text('Startseite'),
              enabled: controller.hasData,
            ),
            PopupMenuItem<MenuOptions>(
                value: MenuOptions.quiz,
                child: const Text('Quiz'),
                enabled: controller.hasData),
            PopupMenuItem<MenuOptions>(
                value: MenuOptions.prices,
                child: const Text('Preise'),
                enabled: controller.hasData
                //&& controller.data!.currentUrl().toString() != programURL
                ),
            const PopupMenuItem<MenuOptions>(
              value: MenuOptions.showDev,
              child: Text('Entwickler'),
            )
          ],
        );
      },
    );
  }

  void _onShowDev(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Phil Roggenbuck"),
      duration: const Duration(seconds: 6),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Github',
        onPressed: () {
          _launchURL("https://github.com/phrogg");
        },
        textColor: Colors.white,
        disabledTextColor: Colors.grey,
      ),
    ));
  }

  void _onShowQuiz(WebViewController? controller, BuildContext context) async {
    await controller?.loadUrl("https://kinodriburg.de/quiz/");
  }

  void _onShowPrices(
      WebViewController? controller, BuildContext context) async {
    await controller?.loadUrl("https://kinodriburg.de/eintrittspreise/");
  }

  void _onShowMainPage(
      WebViewController? controller, BuildContext context) async {
    await controller?.loadUrl("https://kinodriburg.de");
  }

  void _onShowProgramm(
      WebViewController? controller, BuildContext context) async {
    await controller?.loadUrl(programURL);
  }
}
