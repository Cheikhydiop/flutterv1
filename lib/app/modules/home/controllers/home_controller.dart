import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../../models/transaction_model.dart';

class HomeController extends GetxController {
  // Observable list for recent transactions
  var recentTransactions = <TransactionModel>[].obs;
    RxBool isBalanceVisible = true.obs;


  final count = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchRecentTransactions();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }

  void increment() => count.value++;

  // Fetch recent transactions from Firestore
  void fetchRecentTransactions() async {
    try {
      print('Fetching transactions from Firestore...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      print('Documents fetched: ${snapshot.docs.length}');

      // Convert documents to TransactionModel objects
      recentTransactions.value = snapshot.docs.map((doc) {
        try {
          final transaction = TransactionModel.fromFirestore(doc);
          print('Transaction fetched: ${transaction.id}');
          return transaction;
        } catch (e) {
          print('Error parsing document ${doc.id}: $e');
          rethrow;
        }
      }).toList();

      print('Transactions successfully loaded');
    } catch (e) {
      print('Error fetching transactions: $e');
    }
  }

   void toggleBalanceVisibility() {
    isBalanceVisible.value = !isBalanceVisible.value;
  }


}
