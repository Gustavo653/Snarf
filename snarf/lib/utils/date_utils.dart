import 'package:intl/intl.dart';

class DateJSONUtils {
  static String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return DateFormat.Hm().format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  static String formatRelativeTime(String dateString) {
    final date = DateTime.parse(dateString).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Há alguns segundos';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Há $weeks semana${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Há $months mês${months > 1 ? 'es' : ''}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Há $years ano${years > 1 ? 's' : ''}';
    }
  }
}