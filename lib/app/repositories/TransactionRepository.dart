import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new transaction
  Future<void> createTransaction(TransactionModel transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toFirestore());
    } catch (e) {
      rethrow; // Handle or log the error appropriately
    }
  }

  // Fetch a specific transaction by ID
  Future<TransactionModel?> getTransaction(String transactionId) async {
    try {
      final doc = await _firestore.collection('transactions').doc(transactionId).get();
      if (doc.exists) {
        return TransactionModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow; // Handle or log the error appropriately
    }
  }

  // Fetch all transactions for a specific user (as sender or receiver)
  Future<List<TransactionModel>> getTransactionsForUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('transactions')
          .where('senderId', isEqualTo: userId)
          .get();

      // Include transactions where the user is the receiver
      final receiverSnapshot = await _firestore
          .collection('transactions')
          .where('receiverId', isEqualTo: userId)
          .get();

      // Combine and map the transactions
      final transactions = [
        ...querySnapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)),
        ...receiverSnapshot.docs.map((doc) => TransactionModel.fromFirestore(doc))
      ];

      return transactions;
    } catch (e) {
      rethrow; // Handle or log the error appropriately
    }
  }

  // Delete a transaction by ID
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).delete();
    } catch (e) {
      rethrow; // Handle or log the error appropriately
    }
  }

  // Fetch all transactions in the database (optional admin functionality)
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      final querySnapshot = await _firestore.collection('transactions').get();
      return querySnapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow; // Handle or log the error appropriately
    }
  }
}
