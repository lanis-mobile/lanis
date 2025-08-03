import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

class StringListEditor extends StatefulWidget {
  final List<String> initialValues;
  final void Function(List<String> updatedList) onChanged;

  const StringListEditor({
    super.key,
    required this.initialValues,
    required this.onChanged,
  });

  @override
  State<StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<StringListEditor> {
  late List<String> _values;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _values = List.from(widget.initialValues);
  }

  void _addValue(String value) {
    if (value.isEmpty || value.trim().isEmpty || _values.contains(value)) {
      return;
    }

    setState(() {
      _values.add(value);
      widget.onChanged(_values);
    });
    _controller.clear();
  }

  void _removeValue(int index) {
    setState(() {
      _values.removeAt(index);
      widget.onChanged(_values);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).addFilter,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _addValue(_controller.text);
                }
              },
            ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _values.map((value) {
            int index = _values.indexOf(value);
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InputChip(
                label: Text(value),
                onDeleted: () => _removeValue(index),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(2),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
