class ApiResponseHandler {
  static String handleError(dynamic data, int statusCode) {
    if (data is Map) {

      // 1. custom backend errors
      if (data.containsKey('error')) {
        return _mapMessage(data['error'].toString());
      }

      if (data.containsKey('detail')) {
        return _mapMessage(data['detail'].toString());
      }
    }

    // 2. fallback by status code
    switch (statusCode) {
      case 400:
        return "Invalid request. Please check your input.";

      case 401:
        return "Invalid username or password.";

      case 403:
        return "You are not allowed to perform this action.";

      case 404:
        return "Account not found. Please register first.";

      case 500:
        return "Server error. Try again later.";

      default:
        return "Something went wrong.";
    }
  }

  static String _mapMessage(String msg) {
    final lower = msg.toLowerCase();

    // case 1: custom backend for unverified user
    if (lower.contains("account not verified")) {
      return "Account not verified yet.";
    }

    // case 2: wrong credentials OR non-existent user
    if (lower.contains("no active account") ||
        lower.contains("invalid credentials") ||
        lower.contains("user does not exist")) {
      return "Invalid username or password.";
    }

    if (lower.contains("expired")) {
      return "Code expired. Please request a new one.";
    }

    return msg; // fallback
  }
}