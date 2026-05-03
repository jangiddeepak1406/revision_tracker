class RevisionLogic {
  // This function calculates the target date based on your fixed rules
 static DateTime? getScheduledDate(DateTime initialDate, int step) {
  if (step == 0) {
    return initialDate.add(const Duration(days: 3));
  } else if (step == 1) {
    return initialDate.add(const Duration(days: 10));
  } else if (step == 2) {
    return initialDate.add(const Duration(days: 24));
  }
  // If step is 3 or more, there is no "Next Date"
  return null; 
}

  // This helps us display the status of the task
  static String getStatus(DateTime scheduledDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);

    if (scheduled.isBefore(today)) {
      return "Overdue";
    } else if (scheduled.isAtSameMomentAs(today)) {
      return "Due Today";
    } else {
      return "Pending";
    }
  }
}