import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomDateField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const CustomDateField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.firstDate,
    this.lastDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _DateInputFormatter(),
      ],
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText ?? 'dd/mm/aaaa',
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 20),
          onPressed: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: firstDate ?? DateTime(2000),
              lastDate: lastDate ?? DateTime(2100),
            );
            if (pickedDate != null) {
              String day = pickedDate.day.toString().padLeft(2, '0');
              String month = pickedDate.month.toString().padLeft(2, '0');
              String year = pickedDate.year.toString();
              controller.text = '$day/$month/$year';
            }
          },
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 8) {
      digitsOnly = digitsOnly.substring(0, 8);
    }

    String result = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        result += '/';
      }
      result += digitsOnly[i];
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}