class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.kind,
    this.note,
    this.reference,
    this.createdAt,
  });

  final int id;
  final double amount;
  final String kind;
  final String? note;
  final String? reference;
  final DateTime? createdAt;

  bool get isCredit => amount >= 0;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: (json['id'] as num).toInt(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        kind: json['kind'] as String? ?? 'debit',
        note: json['note'] as String?,
        reference: json['reference'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      );
}

class WalletSummary {
  const WalletSummary({
    this.balance = 0,
    this.loyaltyPoints = 0,
    this.transactions = const [],
  });

  final double balance;
  final int loyaltyPoints;
  final List<WalletTransaction> transactions;
}
