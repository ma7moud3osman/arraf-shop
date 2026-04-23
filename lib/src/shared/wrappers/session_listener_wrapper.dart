import 'package:arraf_shop/src/imports/core_imports.dart';

/// Removes the native iOS/Android splash image once Flutter is ready to
/// paint. Landing-route selection lives on the animated splash screen
/// (which is the router's `initialLocation`), so this wrapper no longer
/// forces any navigation — it just tears down the boot splash.
class SessionListenerWrapper extends StatefulWidget {
  final Widget child;
  const SessionListenerWrapper({super.key, required this.child});

  @override
  State<SessionListenerWrapper> createState() => _SessionListenerWrapperState();
}

class _SessionListenerWrapperState extends State<SessionListenerWrapper> {
  bool _nativeSplashRemoved = false;

  @override
  void initState() {
    super.initState();
    // Drop the native boot splash as soon as the Flutter tree mounts. Our
    // AnimatedSplashScreen takes over from here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nativeSplashRemoved) return;
      _nativeSplashRemoved = true;
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
