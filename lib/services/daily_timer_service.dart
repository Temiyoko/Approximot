class DailyTimerService {
  static Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return '$hours:$minutes:$seconds';
  }

  static String formatMilliseconds(int milliseconds) {
    if (milliseconds <= 0) return '00:00:00';
    
    final duration = Duration(milliseconds: milliseconds);
    return formatDuration(duration);
  }
}