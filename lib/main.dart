import 'dart:math';

import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  static const title = 'Flutter App';

  const App({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: title,
        home: HomePage(),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(App.title)),
        body: const Padding(
          padding: EdgeInsets.all(8),
          child: TextEditorWithLineNumbers(),
        ),
      );
}

class TextEditorWithLineNumbers extends StatefulWidget {
  const TextEditorWithLineNumbers({Key? key}) : super(key: key);

  @override
  State<TextEditorWithLineNumbers> createState() =>
      _TextEditorWithLineNumbersState();
}

class _TextEditorWithLineNumbersState extends State<TextEditorWithLineNumbers> {
  final _textController = TextEditingController();
  final _controllers = LinkedScrollControllerGroup();
  late final ScrollController _textScroll;
  late final ScrollController _numbersScroll;
  late final TextStyle _textStyle;
  late final ScrollBehavior _noScrollbarsBehavior;
  late final ScrollBehavior _scrollbarsBehavior;
  final _textFocusNode = FocusNode();
  List<double> _lineHeights = [];

  @override
  void initState() {
    super.initState();
    _textScroll = _controllers.addAndGet();
    _numbersScroll = _controllers.addAndGet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _textStyle =
        Theme.of(context).textTheme.subtitle1!.copyWith(color: Colors.black26);

    _noScrollbarsBehavior =
        ScrollConfiguration.of(context).copyWith(scrollbars: false);

    _scrollbarsBehavior =
        ScrollConfiguration.of(context).copyWith(scrollbars: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _textScroll.dispose();
    _numbersScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50, // HACK: width of four characters
            child: ScrollConfiguration(
              behavior: _noScrollbarsBehavior,
              child: ListView.builder(
                controller: _numbersScroll,
                itemCount: _lineHeights.length,
                shrinkWrap: true,
                physics: null,
                itemBuilder: (context, index) {
                  assert(_lineHeights[index] >= 0);
                  return SizedBox(
                    height: _lineHeights[index],
                    child: ScrollConfiguration(
                      behavior: _scrollbarsBehavior,
                      child: Text('${index + 1}', style: _textStyle),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4), // HACK: match ListView
              child: SizeChangedNotifier(
                onChanged: _sizeChanged,
                child: TextField(
                  scrollController: _textScroll,
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  onChanged: _textChanged,
                  focusNode: _textFocusNode,
                  decoration:
                      const InputDecoration.collapsed(hintText: 'enter text'),
                ),
              ),
            ),
          ),
        ],
      );

  void _sizeChanged() => _textChanged(_textController.text);

  void _textChanged(String value) {
    final ets = _getEditableTextState(_textFocusNode);
    if (ets != null) {
      final lengths = _getLineLengths(value);
      final selections = _getTextSelections(lengths);
      _log('');
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        final singleLineHeight = _getSingleLineHeight(ets);
        final heights = [
          for (final sel in selections)
            _getWrappedLineHeight(ets, sel, singleLineHeight)
        ];
        setState(() => _lineHeights = heights.toList());
      });
    }
  }

  EditableTextState? _getEditableTextState(FocusNode? focus) {
    if (focus?.context == null ||
        focus!.context! is! StatefulElement ||
        (focus.context! as StatefulElement).state is! EditableTextState) {
      return null;
    }

    return (focus.context! as StatefulElement).state as EditableTextState;
  }

  Iterable<int> _getLineLengths(String text) sync* {
    if (text.isEmpty) {
      yield 0;
      return;
    }

    var start = 0;
    for (;;) {
      final i = text.indexOf('\n', start);
      if (i == -1) break;
      yield i - start;
      start = i + 1;
    }

    final len = text.length;
    if (start < len) yield len - start;

    if (text.endsWith('\n')) yield 0;
  }

  Iterable<TextSelection> _getTextSelections(Iterable<int> lengths) sync* {
    var base = 0;
    for (final length in lengths) {
      yield TextSelection(
          baseOffset: base, extentOffset: length == 0 ? base : base + length);
      base = base + length + 1;
    }
  }

  double _getSingleLineHeight(EditableTextState ets) => max(
      ets.renderEditable
          .getEndpointsForSelection(const TextSelection.collapsed(offset: 0))
          .first
          .point
          .dy
          .floorToDouble(),
      19); // HACK

  double _getWrappedLineHeight(
    EditableTextState ets,
    TextSelection selection,
    double singleLineHeight,
  ) {
    final tsps = ets.renderEditable.getEndpointsForSelection(selection);
    final height = max(
      tsps.last.point.dy - tsps.first.point.dy + singleLineHeight,
      singleLineHeight,
    );
    _log(
        '_getWrappedLineHeight for baseOffset= ${selection.baseOffset}, extentOffset= ${selection.extentOffset}: first.dy= ${tsps.first.point.dy}, last.dy= ${tsps.last.point.dy} is $height');
    assert(height >= singleLineHeight);
    return height;
  }

  void _log(Object o) {
    // const log = true;
    const log = false;
    if (log) debugPrint(o.toString());
  }
}

class SizeChangedNotifier extends StatefulWidget {
  final VoidCallback onChanged;
  final Widget child;

  const SizeChangedNotifier({
    required this.onChanged,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  _SizeChangedNotifierState createState() => _SizeChangedNotifierState();
}

class _SizeChangedNotifierState extends State<SizeChangedNotifier> {
  BoxConstraints? _constraints;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (_constraints != constraints) {
            _constraints = constraints;
            WidgetsBinding.instance
                ?.addPostFrameCallback((_) => widget.onChanged());
          }
          return widget.child;
        },
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _constraints = null;
  }
}
