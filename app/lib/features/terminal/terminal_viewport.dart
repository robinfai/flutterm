import 'dart:async';

import 'package:flutter/material.dart';

import 'render_terminal_viewport.dart';
import 'selection_controller.dart';
import 'terminal_input_controller.dart';
import 'terminal_painter_models.dart';

class TerminalViewportController extends ChangeNotifier {
  TerminalFrameDiff _frame = TerminalFrameDiff.empty;

  TerminalFrameDiff get frame => _frame;

  void updateFrame(TerminalFrameDiff value) {
    _frame = value;
    notifyListeners();
  }
}

class TerminalViewport extends StatefulWidget {
  const TerminalViewport({
    super.key,
    required this.controller,
    required this.selectionController,
    required this.inputController,
    required this.onScrollLines,
    this.focusNode,
  });

  final TerminalViewportController controller;
  final SelectionController selectionController;
  final TerminalInputController inputController;
  final ValueChanged<int> onScrollLines;
  final FocusNode? focusNode;

  @override
  State<TerminalViewport> createState() => _TerminalViewportState();
}

class _TerminalViewportState extends State<TerminalViewport> {
  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  FocusNode? _ownedFocusNode;
  FocusNode? _listenedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownedFocusNode ??= FocusNode(debugLabel: 'terminal-viewport'));

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleFrameUpdate);
    _bindFocusNodeListener();
    _syncCursorBlinkTimer();
  }

  @override
  void didUpdateWidget(covariant TerminalViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleFrameUpdate);
      widget.controller.addListener(_handleFrameUpdate);
    }
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      _unbindFocusNodeListener();
      _bindFocusNodeListener();
    }
    _syncCursorBlinkTimer();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleFrameUpdate);
    _unbindFocusNodeListener();
    _cursorBlinkTimer?.cancel();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _bindFocusNodeListener() {
    final focusNode = _focusNode;
    _listenedFocusNode = focusNode;
    focusNode.addListener(_handleFocusChange);
  }

  void _unbindFocusNodeListener() {
    _listenedFocusNode?.removeListener(_handleFocusChange);
    _listenedFocusNode = null;
  }

  void _handleFrameUpdate() {
    if (!mounted) {
      return;
    }
    _syncCursorBlinkTimer();
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }
    _syncCursorBlinkTimer();
  }

  bool get _shouldBlinkCursor {
    final frameCursorVisible = widget.controller.frame.cursor.visible;
    return _focusNode.hasFocus && frameCursorVisible;
  }

  void _syncCursorBlinkTimer() {
    if (_shouldBlinkCursor) {
      _cursorBlinkTimer ??= Timer.periodic(
        const Duration(milliseconds: 650),
        (_) {
          if (!mounted || !_shouldBlinkCursor) {
            return;
          }
          setState(() {
            _cursorVisible = !_cursorVisible;
          });
        },
      );
      return;
    }

    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimer = null;
    if (!_cursorVisible) {
      setState(() {
        _cursorVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (_, event) => widget.inputController.handle(event),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focusNode.requestFocus,
        child: _TerminalViewportSurface(
          controller: widget.controller,
          selectionController: widget.selectionController,
          onScrollLines: widget.onScrollLines,
          cursorVisible: _cursorVisible,
        ),
      ),
    );
  }
}

class _TerminalViewportSurface extends LeafRenderObjectWidget {
  const _TerminalViewportSurface({
    required this.controller,
    required this.selectionController,
    required this.onScrollLines,
    required this.cursorVisible,
  });

  final TerminalViewportController controller;
  final SelectionController selectionController;
  final ValueChanged<int> onScrollLines;
  final bool cursorVisible;

  @override
  RenderTerminalViewport createRenderObject(BuildContext context) {
    return RenderTerminalViewport(
      controller: controller,
      selectionController: selectionController,
      onScrollLines: onScrollLines,
      cursorVisible: cursorVisible,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTerminalViewport renderObject,
  ) {
    renderObject
      ..controller = controller
      ..selectionController = selectionController
      ..onScrollLines = onScrollLines
      ..cursorVisible = cursorVisible
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}
