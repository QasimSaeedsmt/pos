import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/auth_constants.dart';
import '../providers/auth_provider.dart';
import '../constants/auth_strings.dart';
import '../constants/auth_measurements.dart';

class KeepMeLoggedInCheckbox extends StatefulWidget {
  const KeepMeLoggedInCheckbox({super.key});

  @override
  State<KeepMeLoggedInCheckbox> createState() => _KeepMeLoggedInCheckboxState();
}

class _KeepMeLoggedInCheckboxState extends State<KeepMeLoggedInCheckbox> {
  bool _isChecked = false;

  @override
  void initState() {
    super.initState();
    _loadInitialValue();
  }

  Future<void> _loadInitialValue() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    setState(() {
      _isChecked = authProvider.keepMeLoggedIn;
    });
  }

  Future<void> _onChanged(bool? value) async {
    if (value == null) return;

    setState(() {
      _isChecked = value;
    });

    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    await authProvider.setKeepMeLoggedInSilent(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CheckboxListTile(
      title: Text(
        AuthStrings.keepMeLoggedIn,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
      ),
      value: _isChecked,
      onChanged: _onChanged,
      activeColor: const Color(AuthConstants.primaryColor),
      checkColor: Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusSmall),
      ),
      tileColor: isDark
          ? const Color(AuthConstants.darkSurfaceColor).withOpacity(AuthMeasurements.opacityMedium)
          : Colors.grey[100],
    );
  }
}