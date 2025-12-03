// // custom_theme_creator.dart
// import 'package:flutter/material.dart';
// import 'package:mpcm/theme_selector_bottom_sheet.dart';
// import 'package:provider/provider.dart';
// import 'app_theme.dart';
// import 'theme_provider.dart' hide GradientThemeManager;
//
//
// class CustomThemeCreator extends StatefulWidget {
//   final GradientTheme? existingTheme;
//
//   const CustomThemeCreator({Key? key, this.existingTheme}) : super(key: key);
//
//   @override
//   State<CustomThemeCreator> createState() => _CustomThemeCreatorState();
// }
//
// class _CustomThemeCreatorState extends State<CustomThemeCreator> {
//   final _nameController = TextEditingController();
//   final List<Color> _colors = [Colors.blue, Colors.purple];
//   bool _isDark = false;
//
//   @override
//   void initState() {
//     super.initState();
//     if (widget.existingTheme != null) {
//       _nameController.text = widget.existingTheme!.name;
//       _colors.clear();
//       _colors.addAll(GradientThemeManager().hexToColors(widget.existingTheme!.colors));
//       _isDark = widget.existingTheme!.isDark;
//     }
//   }
//
//   @override
//   void dispose() {
//     _nameController.dispose();
//     super.dispose();
//   }
//
//   void _addColor() {
//     setState(() {
//       _colors.add(Colors.blue);
//     });
//   }
//
//   void _removeColor(int index) {
//     setState(() {
//       if (_colors.length > 2) {
//         _colors.removeAt(index);
//       }
//     });
//   }
//
//   void _updateColor(int index, Color color) {
//     setState(() {
//       _colors[index] = color;
//     });
//   }
//
//   void _saveTheme() {
//     if (_nameController.text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter a theme name')),
//       );
//       return;
//     }
//
//     final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
//     final hexColors = _colors.map((color) => themeProvider.colorToHex(color)).toList();
//
//     final newTheme = GradientTheme(
//       name: _nameController.text,
//       colors: hexColors,
//       isDark: _isDark, primaryColor: '', secondaryColor: '', accentColor: '',
//     );
//
//     if (widget.existingTheme != null) {
//       themeProvider.updateCustomTheme(widget.existingTheme!, newTheme);
//     } else {
//       themeProvider.addCustomTheme(newTheme);
//     }
//
//     Navigator.pop(context);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(widget.existingTheme != null ? 'Edit Theme' : 'Create Custom Theme'),
//       content: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: _nameController,
//               decoration: const InputDecoration(
//                 labelText: 'Theme Name',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Row(
//               children: [
//                 const Text('Dark Theme:'),
//                 const SizedBox(width: 10),
//                 Switch(
//                   value: _isDark,
//                   onChanged: (value) => setState(() => _isDark = value),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             const Text(
//               'Gradient Colors:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             ..._colors.asMap().entries.map((entry) {
//               final index = entry.key;
//               final color = entry.value;
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Container(
//                         height: 50,
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(colors: [color, color]),
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(color: Colors.grey),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     ElevatedButton(
//                       onPressed: () async {
//                         final newColor = await showDialog<Color>(
//                           context: context,
//                           builder: (context) => ColorPickerDialog(initialColor: color),
//                         );
//                         if (newColor != null) {
//                           _updateColor(index, newColor);
//                         }
//                       },
//                       child: const Text('Change'),
//                     ),
//                     if (_colors.length > 2) ...[
//                       const SizedBox(width: 10),
//                       IconButton(
//                         onPressed: () => _removeColor(index),
//                         icon: const Icon(Icons.delete, color: Colors.red),
//                       ),
//                     ],
//                   ],
//                 ),
//               );
//             }),
//             const SizedBox(height: 10),
//             ElevatedButton.icon(
//               onPressed: _addColor,
//               icon: const Icon(Icons.add),
//               label: const Text('Add Color'),
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: _saveTheme,
//           child: const Text('Save Theme'),
//         ),
//       ],
//     );
//   }
// }
//
// class ColorPickerDialog extends StatefulWidget {
//   final Color initialColor;
//
//   const ColorPickerDialog({Key? key, required this.initialColor}) : super(key: key);
//
//   @override
//   State<ColorPickerDialog> createState() => _ColorPickerDialogState();
// }
//
// class _ColorPickerDialogState extends State<ColorPickerDialog> {
//   late Color _selectedColor;
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedColor = widget.initialColor;
//   }
//
//   final List<Color> _presetColors = [
//     Colors.red,
//     Colors.pink,
//     Colors.purple,
//     Colors.deepPurple,
//     Colors.indigo,
//     Colors.blue,
//     Colors.lightBlue,
//     Colors.cyan,
//     Colors.teal,
//     Colors.green,
//     Colors.lightGreen,
//     Colors.lime,
//     Colors.yellow,
//     Colors.amber,
//     Colors.orange,
//     Colors.deepOrange,
//     Colors.brown,
//     Colors.grey,
//     Colors.blueGrey,
//     Colors.black,
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Pick a Color'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 100,
//             height: 100,
//             decoration: BoxDecoration(
//               color: _selectedColor,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey),
//             ),
//           ),
//           const SizedBox(height: 20),
//           const Text('Preset Colors:'),
//           const SizedBox(height: 10),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: _presetColors.map((color) {
//               return GestureDetector(
//                 onTap: () => setState(() => _selectedColor = color),
//                 child: Container(
//                   width: 40,
//                   height: 40,
//                   decoration: BoxDecoration(
//                     color: color,
//                     borderRadius: BorderRadius.circular(6),
//                     border: Border.all(
//                       color: _selectedColor == color ? Colors.black : Colors.grey,
//                       width: _selectedColor == color ? 3 : 1,
//                     ),
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () => Navigator.pop(context, _selectedColor),
//           child: const Text('Select'),
//         ),
//       ],
//     );
//   }
// }