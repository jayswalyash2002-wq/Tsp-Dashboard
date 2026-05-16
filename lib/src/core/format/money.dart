String formatRupeesFromPaise(int paise) {
  final rupees = paise / 100.0;
  final isWhole = (paise % 100) == 0;
  return isWhole ? rupees.toStringAsFixed(0) : rupees.toStringAsFixed(2);
}

