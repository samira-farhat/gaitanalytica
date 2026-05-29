import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/api_response_handler.dart';

import 'login_screen.dart';
import 'reset_password_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isPasswordReset; // 1. added this flag

  const OtpScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String? _errorMessage;
  bool _isResending = false;
  String? _infoMessage;

  bool _canResend = false;
  int _resendSeconds = 30;
  Timer? _resendTimer;

  int _otpExpirySeconds = 600;
  Timer? _otpExpiryTimer;

  final List<TextEditingController> _controllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    _startOtpExpiryTimer();
  }

  void _startResendCooldown() {
    _canResend = false;
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        setState(() {
          _canResend = true;
          _isResending = false;
        });
        timer.cancel();
      }
    });
  }

  void _startOtpExpiryTimer() {
    _otpExpiryTimer?.cancel();
    _otpExpirySeconds = 600;
    _otpExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpExpirySeconds > 0) {
        setState(() => _otpExpirySeconds--);
      } else {
        timer.cancel();
        setState(() => _errorMessage = "Verification code expired");
      }
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    _otpExpiryTimer?.cancel();
    super.dispose();
  }

  // function to verify otp with backend
  Future<void> _verifyOtp() async {
    String otp = _controllers.map((e) => e.text).join();

    if (otp.length < 6) {
      setState(() => _errorMessage = "Please enter the 6-digit code");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/verify-otp/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": otp,
          "purpose": widget.isPasswordReset ? "password_reset" : "registration",
        }),
      );

      // Guard: Ensure screen is still active
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _errorMessage = null;
          _infoMessage = "Code verified successfully";
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return; // Guard: Final check before navigation
          if (widget.isPasswordReset) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ResetPasswordScreen(email: widget.email, otp: otp)),
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
            );
          }
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = ApiResponseHandler.handleError(data, response.statusCode);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResponseHandler.handleError({"error": e.toString()}, 500);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // function to resend otp
  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final url = widget.isPasswordReset
          ? '${ApiConfig.baseUrl}/api/password-reset-request/'
          : '${ApiConfig.baseUrl}/api/resend-otp/';

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (!mounted) return; // Guard

      if (response.statusCode == 200) {
        setState(() {
          _infoMessage = "New code sent to your email";
          _otpExpirySeconds = 600;
        });
        _startResendCooldown();
        _startOtpExpiryTimer();
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = ApiResponseHandler.handleError(data, response.statusCode);
        });
        if (response.statusCode == 429) _startResendCooldown();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResponseHandler.handleError({"error": e.toString()}, 500);
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureWhite,
      appBar: AppBar(
        backgroundColor: AppColors.pureWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.onyxCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(height: 40),

              Icon(Icons.mark_email_read_outlined, size: 80, color: AppColors.skeletonBlue),

              SizedBox(height: 30),

              // dynamic title based on context
              Text(
                widget.isPasswordReset ? "Reset Password" : "Verify Email",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
              ),

              SizedBox(height: 10),

              Text(
                "code expires in "
                    "${(_otpExpirySeconds ~/ 60).toString().padLeft(2, '0')}:"
                    "${(_otpExpirySeconds % 60).toString().padLeft(2, '0')}",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
              ),

              Text(
                "enter the code sent to ${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.terrainGrey),
              ),

              SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),

              SizedBox(height: 20),

              if (_errorMessage != null)
                Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              if (_infoMessage != null)
                Text(_infoMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),

              SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.skeletonBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("VERIFY", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),

              SizedBox(height: 20),

              TextButton(
                onPressed: (_isResending || !_canResend) ? null : _resendOtp,
                child: _isResending
                    ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                  _canResend ? "didn't receive a code? resend" : "resend code in $_resendSeconds s",
                  style: TextStyle(color: AppColors.skeletonBlue, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onyxCharcoal),
        keyboardType: TextInputType.number,
        inputFormatters: [LengthLimitingTextInputFormatter(1), FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.skeletonBlue, width: 2)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
          if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
        },
      ),
    );
  }
}