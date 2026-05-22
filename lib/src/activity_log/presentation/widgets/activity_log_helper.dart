import 'package:flutter/material.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../../domain/entities/activity_log_enums.dart';

extension ActivityLogEntryX on ActivityLogEntry {
  String get humanReadableAction {
    switch (action) {
      case ActivityAction.userLoggedIn:
        return 'Signed in';
      case ActivityAction.userLoggedOut:
        return 'Signed out';
      case ActivityAction.passwordChanged:
        return 'Changed password';
      case ActivityAction.emailVerified:
        return 'Verified email';
      case ActivityAction.businessCreated:
        return 'Created business: $targetName';
      case ActivityAction.businessUpdated:
        return 'Updated business details';
      case ActivityAction.businessSettingsChanged:
        return 'Changed business settings';
      case ActivityAction.memberAdded:
        return 'Added $targetName as ${metadata['role']}';
      case ActivityAction.memberRoleChanged:
        return 'Changed $targetName\'s role to ${metadata['newRole']}';
      case ActivityAction.memberSuspended:
        return 'Suspended membership: $targetName';
      case ActivityAction.memberRevoked:
        return 'Revoked membership: $targetName';
      case ActivityAction.invitationSent:
        return 'Sent invitation to ${metadata['email']}';
      case ActivityAction.invitationAccepted:
        return 'Accepted invitation from $targetName';
      case ActivityAction.orderCreated:
        return 'New order created';
      case ActivityAction.orderModified:
        return 'Modified order: $targetId';
      case ActivityAction.orderCancelled:
        return 'Cancelled order: $targetName';
      case ActivityAction.orderCompleted:
        return 'Order completed';
      case ActivityAction.expenseAdded:
        return 'Added expense: $targetName';
      case ActivityAction.expenseModified:
        return 'Modified expense: $targetName';
      case ActivityAction.expenseDeleted:
        return 'Deleted expense: $targetName';
      case ActivityAction.menuItemAdded:
        return 'Added menu item: $targetName';
      case ActivityAction.menuItemModified:
        return 'Modified menu item: $targetName';
      case ActivityAction.menuItemDeleted:
        return 'Deleted menu item: $targetName';
      case ActivityAction.invoiceCreated:
        return 'Created invoice: $targetName';
      case ActivityAction.invoiceSent:
        return 'Sent invoice: $targetName';
      case ActivityAction.invoicePaid:
        return 'Invoice paid: $targetName';
      case ActivityAction.invoiceVoided:
        return 'Voided invoice: $targetName';
      case ActivityAction.balanceUpdated:
        return 'Updated balance';
      case ActivityAction.fundAdded:
        return 'Added funds: Rs. ${metadata['amount']}';
      case ActivityAction.paymentRecorded:
        return 'Recorded payment: Rs. ${metadata['amount']}';
      case ActivityAction.businessOpened:
        return 'Business opened';
      case ActivityAction.businessClosed:
        return 'Business closed';
      case ActivityAction.inventoryItemAdded:
        return 'Added ${metadata['initialStock'] ?? ''} $targetName'.trim();
      case ActivityAction.inventoryItemModified:
        return 'Modified inventory item: $targetName';
      case ActivityAction.inventoryItemDeleted:
        return 'Deleted inventory item: $targetName';
      case ActivityAction.inventoryDeducted:
        return 'Inventory deducted from ${metadata['orderItems'] ?? 'order'}';
      case ActivityAction.inventoryStockAdjusted:
        if (metadata['reason'] == 'Order Cancelled') {
          return 'Inventory restored from cancelled order';
        }
        return 'Updated $targetName stock from ${metadata['previousStock']} → ${metadata['newStock']}';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case ActivityCategory.authentication:
        return Icons.lock_outline;
      case ActivityCategory.business:
        return Icons.business_outlined;
      case ActivityCategory.membership:
        return Icons.people_outline;
      case ActivityCategory.operational:
        return Icons.receipt_long_outlined;
      case ActivityCategory.financial:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color get categoryColor {
    switch (category) {
      case ActivityCategory.authentication:
        return Colors.blue;
      case ActivityCategory.business:
        return Colors.purple;
      case ActivityCategory.membership:
        return Colors.orange;
      case ActivityCategory.operational:
        return Colors.green;
      case ActivityCategory.financial:
        return Colors.teal;
    }
  }
}
