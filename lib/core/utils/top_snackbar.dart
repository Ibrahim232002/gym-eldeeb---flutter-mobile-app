import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeTopSnackBarEntry;

/// Displays a SnackBar-style message at the top of the root overlay.
///
/// Existing SnackBar content, color, duration, and action are preserved. This
/// keeps notifications visible above the current route instead of below it.
void showTopSnackBar(BuildContext context, SnackBar snackBar) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final previousEntry = _activeTopSnackBarEntry;
  if (previousEntry?.mounted == true) {
    previousEntry!.remove();
  }
  _activeTopSnackBarEntry = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopSnackBarOverlay(
      snackBar: snackBar,
      onDismiss: () {
        if (identical(_activeTopSnackBarEntry, entry)) {
          _activeTopSnackBarEntry = null;
        }
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _activeTopSnackBarEntry = entry;
  overlay.insert(entry);
}

class _TopSnackBarOverlay extends StatefulWidget {
  final SnackBar snackBar;
  final VoidCallback onDismiss;

  const _TopSnackBarOverlay({
    required this.snackBar,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBarOverlay> createState() => _TopSnackBarOverlayState();
}

class _TopSnackBarOverlayState extends State<_TopSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
    _timer = Timer(widget.snackBar.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackBarTheme = theme.snackBarTheme;
    final backgroundColor = widget.snackBar.backgroundColor ??
        snackBarTheme.backgroundColor ??
        theme.colorScheme.inverseSurface;
    final contentStyle = snackBarTheme.contentTextStyle ??
        TextStyle(color: theme.colorScheme.onInverseSurface, fontSize: 14);

    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _controller,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -4) _dismiss();
              },
              child: Material(
                color: backgroundColor,
                elevation: widget.snackBar.elevation ?? 6,
                shape: widget.snackBar.shape ??
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: contentStyle,
                          child: widget.snackBar.content,
                        ),
                      ),
                      if (widget.snackBar.action != null)
                        TextButton(
                          onPressed: () {
                            widget.snackBar.action!.onPressed();
                            _dismiss();
                          },
                          child: Text(
                            widget.snackBar.action!.label,
                            style: TextStyle(
                              color: widget.snackBar.action!.textColor ??
                                  theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (widget.snackBar.showCloseIcon == true)
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          onPressed: _dismiss,
                          icon: Icon(
                            Icons.close_rounded,
                            color: widget.snackBar.closeIconColor ??
                                theme.colorScheme.onInverseSurface,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
