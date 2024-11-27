import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Créer un nouvel utilisateur
  Future<void> createUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toFirestore());
  }

  // Récupérer un utilisateur
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .get();

    return doc.exists ? UserModel.fromFirestore(doc, id: '') : null;
  }

  // Créer une transaction et mettre à jour le solde
  Future<void> createTransaction(TransactionModel transaction, String userId) async {
    // Ajouter la transaction
    DocumentReference transactionRef = await _firestore
        .collection('transactions')
        .add(transaction.toFirestore());

    // Mettre à jour l'utilisateur avec l'ID de la transaction
    await _firestore.collection('users').doc(userId).update({
      'transactionIds': FieldValue.arrayUnion([transactionRef.id])
    });

    // Mettre à jour le solde de l'utilisateur
    await updateUserBalance(userId, transaction.amount);
  }

  // Récupérer les transactions d'un utilisateur
  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    final querySnapshot = await _firestore
        .collection('transactions')
        .where('senderId', isEqualTo: userId)
        .get();

    return querySnapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
  }

  // Mettre à jour le solde de l'utilisateur
  Future<void> updateUserBalance(String userId, double amount) async {
    final userDoc = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      final user = UserModel.fromFirestore(snapshot, id: '');
      final newBalance = (user.solde ?? 0) + amount;
      transaction.update(userDoc, {'balance': newBalance});
    });
  }
}