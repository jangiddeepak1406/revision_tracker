// We removed the imports because we don't need the package anymore!

class NotificationService {
  // An empty init so main.dart doesn't complain
  static Future<void> init() async {
    print("Notification Service: Standby Mode (No packages loaded)");
  }

  // An empty schedule function so your buttons don't break
  static Future<void> scheduleNotification(int id, String title, DateTime date) async {
    // Does nothing, keeps the app stable
  }
}