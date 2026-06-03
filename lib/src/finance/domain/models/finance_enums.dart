enum FinanceTransactionType {
  fund,
  expense,
  transfer;

  static FinanceTransactionType fromString(String? val) {
    return FinanceTransactionType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => FinanceTransactionType.expense,
    );
  }
}

enum FinanceAccount {
  cash,
  bank;

  static FinanceAccount fromString(String? val) {
    return FinanceAccount.values.firstWhere(
      (e) => e.name == val,
      orElse: () => FinanceAccount.cash,
    );
  }
}

enum FinanceAuditAction {
  created,
  edited,
  deleted;

  static FinanceAuditAction fromString(String? val) {
    return FinanceAuditAction.values.firstWhere(
      (e) => e.name == val,
      orElse: () => FinanceAuditAction.created,
    );
  }
}
