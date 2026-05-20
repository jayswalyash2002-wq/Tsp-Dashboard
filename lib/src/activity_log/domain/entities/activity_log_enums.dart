enum ActivityAction {
  // Authentication
  userLoggedIn,
  userLoggedOut,
  passwordChanged,
  emailVerified,

  // Business
  businessCreated,
  businessUpdated,
  businessSettingsChanged,

  // Membership
  memberAdded,
  memberRoleChanged,
  memberSuspended,
  memberRevoked,
  invitationSent,
  invitationAccepted,

  // Operational
  orderCreated,
  orderModified,
  orderCancelled,
  orderCompleted,
  expenseAdded,
  expenseModified,
  expenseDeleted,
  menuItemAdded,
  menuItemModified,
  menuItemDeleted,
  invoiceCreated,
  invoiceSent,
  invoicePaid,
  invoiceVoided,
  businessOpened,
  businessClosed,

  // Financial
  balanceUpdated,
  fundAdded,
  paymentRecorded,
}

enum ActivityCategory {
  authentication,
  business,
  membership,
  operational,
  financial,
}
