import 'package:flutter/material.dart';

class RestartApp extends StatefulWidget {
  const RestartApp({super.key, this.child});

  final Widget? child;

  static void rebirth(BuildContext context) =>
      context.findAncestorStateOfType<_RestartAppState>()?.restartApp();

  @override
  State<StatefulWidget> createState() => _RestartAppState();
}

class _RestartAppState extends State<RestartApp> {
  Key key = UniqueKey();

  void restartApp() => setState(() => key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: key, child: widget.child ?? Container());
}
