enum OrderStatus {
  pending,
  cutting,
  stitching,
  ready,
  delivered,
  cancelled;

  String get label {
    switch (this) {
      case pending:
        return 'Pending';
      case cutting:
        return 'Cutting';
      case stitching:
        return 'Stitching';
      case ready:
        return 'Ready';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case pending:
        return '⏳';
      case cutting:
        return '✂';
      case stitching:
        return '🧵';
      case ready:
        return '✅';
      case delivered:
        return '📦';
      case cancelled:
        return '❌';
    }
  }
}

enum CustomerGender {
  male,
  female,
  child;

  String get label {
    switch (this) {
      case male:
        return 'Men';
      case female:
        return 'Women';
      case child:
        return 'Children';
    }
  }

  String get emoji {
    switch (this) {
      case male:
        return '👔';
      case female:
        return '👗';
      case child:
        return '👕';
    }
  }
}

enum MeasurementCategory {
  men,
  women,
  children;

  String get label {
    switch (this) {
      case men:
        return 'Men';
      case women:
        return 'Women';
      case children:
        return 'Children';
    }
  }
}

enum PaymentMethod { cash, card, online }

enum ReportPeriod { today, thisMonth, lastMonth, custom }

enum NavSection { dashboard, clients, orders, measurements, reports, profile, reminders }
