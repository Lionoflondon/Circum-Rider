import 'package:flutter/services.dart';

class AmountFormatter extends TextInputFormatter {
  static const int _maxDecimalDigits = 2;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Handling Backspace
    if (oldValue.text.length >= newValue.text.length) {
      return newValue;
    }

    // Check for a single decimal separator
    if (newValue.text.indexOf('.') != newValue.text.lastIndexOf('.')) {
      return oldValue;
    }

    // Check for leading zeros
    if (newValue.text.startsWith('0') && newValue.text.length > 1) {
      if (newValue.text[1] != '.') {
        return TextEditingValue(
          text: newValue.text.substring(1),
          selection: TextSelection.collapsed(offset: newValue.text.length - 1),
        );
      }
    }

    // Check for multiple leading decimals
    if (newValue.text.startsWith('.')) {
      return TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    // Limiting the number of decimal digits
    int indexOfDecimal = newValue.text.indexOf('.');
    if (indexOfDecimal != -1 &&
        newValue.text.substring(indexOfDecimal + 1).length >
            _maxDecimalDigits) {
      return oldValue;
    }

    // Limiting the maximum amount
    double? value = double.tryParse(newValue.text);
    if (value != null && value > 999999.99) {
      return oldValue;
    }

    return newValue;
  }
}
