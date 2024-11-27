import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String senderId;
  final String receiverId;
  final double amount;
  final DateTime timestamp;
  final String description;
  final String status;
  final String? receiverNumber; // Numéro de réception (optionnel)

  TransactionModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.timestamp,
    this.description = '',
    this.status = 'pending',
    this.receiverNumber,
  });

  /// Getter for the date part of the timestamp
  DateTime get date => DateTime(timestamp.year, timestamp.month, timestamp.day);

  /// Convert the model to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'amount': amount,
      'timestamp': timestamp,
      'description': description,
      'status': status,
      'receiverNumber': receiverNumber, // Inclure le numéro de réception
    };
  }

  /// Factory constructor to create an instance from Firestore
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: data['id'] ?? doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      receiverNumber: data['receiverNumber'], // Récupérer le numéro s'il existe
    );
  }

  /// Factory constructor to create a new transaction instance
  factory TransactionModel.create({
    required String senderId,
    required String receiverId,
    required double amount,
    String description = '',
    String? receiverNumber, // Ajouter le numéro de réception en option
  }) {
    return TransactionModel(
      id: '', // Firestore générera un ID automatiquement
      senderId: senderId,
      receiverId: receiverId,
      amount: amount,
      timestamp: DateTime.now(),
      description: description,
      status: 'pending',
      receiverNumber: receiverNumber, // Assigner le numéro ici
    );
  }
}
