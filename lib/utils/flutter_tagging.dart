import 'dart:async';
import 'package:flutter/material.dart';

abstract class Taggable {
  const Taggable();
  List<Object> get props;
}

class SuggestionConfiguration {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;

  SuggestionConfiguration({required this.title, this.subtitle, this.leading});
}

class ChipConfiguration {
  final Widget label;
  final Widget? avatar;

  ChipConfiguration({required this.label, this.avatar});
}

class TextFieldConfiguration {
  final InputDecoration decoration;
  final bool autofocus;

  TextFieldConfiguration({
    this.decoration = const InputDecoration(),
    this.autofocus = false,
  });
}

class FlutterTagging<T extends Taggable> extends StatefulWidget {
  final List<T> initialItems;
  final TextFieldConfiguration textFieldConfiguration;
  final SuggestionConfiguration Function(T) configureSuggestion;
  final ChipConfiguration Function(T) configureChip;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final T Function(T) onAdded;
  final Future<List<T>> Function(String) findSuggestions;

  const FlutterTagging({
    super.key,
    required this.initialItems,
    required this.textFieldConfiguration,
    required this.configureSuggestion,
    required this.configureChip,
    this.loadingBuilder,
    this.emptyBuilder,
    required this.onAdded,
    required this.findSuggestions,
  });

  @override
  State<FlutterTagging<T>> createState() => _FlutterTaggingState<T>();
}

class _FlutterTaggingState<T extends Taggable>
    extends State<FlutterTagging<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<T> _suggestions = [];
  bool _isLoading = false;
  bool _hasQueried = false;
  Timer? _debounce;

  List<T> get _selectedItems => widget.initialItems;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _controller.text.trim();
      if (query.isEmpty) {
        setState(() {
          _suggestions = [];
          _hasQueried = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _hasQueried = true;
      });

      widget
          .findSuggestions(query)
          .then((results) {
            if (!mounted) return;
            setState(() {
              _suggestions = results
                  .where(
                    (item) => !_selectedItems.any(
                      (selected) => _arePropsEqual(item.props, selected.props),
                    ),
                  )
                  .toList();
              _isLoading = false;
            });
          })
          .catchError((error) {
            if (!mounted) return;
            setState(() {
              _suggestions = [];
              _isLoading = false;
            });
          });
    });
  }

  bool _arePropsEqual(List<Object> props1, List<Object> props2) {
    if (props1.length != props2.length) return false;
    for (int i = 0; i < props1.length; i++) {
      if (props1[i] != props2[i]) return false;
    }
    return true;
  }

  void _addItem(T item) {
    final newItem = widget.onAdded(item);
    setState(() {
      _selectedItems.add(newItem);
      _controller.clear();
      _suggestions.clear();
      _hasQueried = false;
    });
  }

  void _removeItem(T item) {
    setState(() {
      _selectedItems.removeWhere(
        (selected) => _arePropsEqual(item.props, selected.props),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedItems.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _selectedItems.map((item) {
              final chipConfig = widget.configureChip(item);
              return InputChip(
                label: chipConfig.label,
                avatar: chipConfig.avatar,
                onDeleted: () => _removeItem(item),
                deleteIcon: const Icon(Icons.cancel, size: 18),
              );
            }).toList(),
          ),
        if (_selectedItems.isNotEmpty) const SizedBox(height: 8.0),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.textFieldConfiguration.autofocus,
          decoration: widget.textFieldConfiguration.decoration,
          onSubmitted: (_) {
            // Optional: Handle submission
          },
        ),
        if (_isLoading)
          widget.loadingBuilder?.call(context) ??
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              )
        else if (_hasQueried && _suggestions.isEmpty)
          widget.emptyBuilder?.call(context) ??
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No tags found'),
              )
        else if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                final sugConfig = widget.configureSuggestion(item);
                return ListTile(
                  leading: sugConfig.leading,
                  title: sugConfig.title,
                  subtitle: sugConfig.subtitle,
                  onTap: () => _addItem(item),
                );
              },
            ),
          ),
      ],
    );
  }
}
