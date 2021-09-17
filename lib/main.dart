import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

// TODO: fix the fencepost
// TODO: make the scrollbars always show

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
  final _textFocusNode = FocusNode();
  List<double> _lineHeights = [19];

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
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
              ),
              child: ListView.builder(
                controller: _numbersScroll,
                itemCount: _lineHeights.length,
                shrinkWrap: true,
                physics: null,
                itemBuilder: (context, index) => SizedBox(
                  height: _lineHeights[index],
                  child: Text('${index + 1}', style: _textStyle),
                ),
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
      final offsets = _getNewlineOffsets(value);
      final selections = _getTextSelections(offsets);
      final heights = [for (final sel in selections) _getLineHeight(ets, sel)];
      setState(() => _lineHeights = heights.toList());
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

  Iterable<int> _getNewlineOffsets(String text) sync* {
    var start = 0;
    for (;;) {
      final i = text.indexOf('\n', start);
      if (i == -1) break;
      yield i;
      start = i + 1;
    }

    // dummy one up for the last line
    yield text.length - 1;
  }

  Iterable<TextSelection> _getTextSelections(Iterable<int> offsets) sync* {
    var base = 0;
    for (final extent in offsets) {
      yield TextSelection(baseOffset: base, extentOffset: extent);
      base = extent + 1;
    }
  }

  double _getLineHeight(EditableTextState ets, TextSelection selection) {
    final tsps = ets.renderEditable.getEndpointsForSelection(selection);
    return tsps.last.point.dy - tsps.first.point.dy + 19; // HACK
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
  var _constraints = BoxConstraints.tight(Size.zero);

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
    _constraints = BoxConstraints.tight(Size.zero);
  }
}
