import 'package:flutter/material.dart';

class AppMessageBox extends StatelessWidget {
  final String message;
  final bool isError;

  const AppMessageBox({
    super.key,
    required this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isError ? Colors.red : Colors.green).withOpacity(0.3),
        ),
      ),

      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError ? Colors.red : Colors.green,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}