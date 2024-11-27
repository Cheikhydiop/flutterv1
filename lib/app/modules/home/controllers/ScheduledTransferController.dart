import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ScheduledTransferController extends GetxController {
  // Instance de Firestore pour les interactions avec la base de données
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Instance d'authentification Firebase
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Logger pour le suivi et le débogage
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // Variables observables pour la gestion de l'état
  final Rx<String> userId = Rx<String>('');
  final RxList<Map<String, dynamic>> planifications = RxList<Map<String, dynamic>>([]);

  // Types de planifications prédéfinis
  final RxList<Map<String, String>> planificationTypes = RxList<Map<String, String>>([
    {'label': 'Épargne', 'value': 'epargne'},
    {'label': 'Investissement', 'value': 'investissement'},
    {'label': 'Projet', 'value': 'projet'},
    {'label': 'Objectif Personnel', 'value': 'objectif_personnel'}
  ]);

  // Fréquences de planification prédéfinies
  final RxList<Map<String, String>> frequencies = RxList<Map<String, String>>([
    {'label': 'Quotidienne', 'value': 'daily'},
    {'label': 'Hebdomadaire', 'value': 'weekly'},
    {'label': 'Mensuelle', 'value': 'monthly'},
    {'label': 'Trimestrielle', 'value': 'quarterly'},
    {'label': 'Annuelle', 'value': 'yearly'}
  ]);

  // Variables d'état
  RxBool isLoading = false.obs;
  RxString errorMessage = ''.obs;
  RxBool isSuccessful = false.obs;

  // Référence à la collection des planifications
  late final CollectionReference<Map<String, dynamic>> _planificationsRef;

  @override
  void onInit() {
    super.onInit();
    _initializeCollectionRefs();
    _initializeUserListener();
  }

  // Initialisation des références de collection Firestore
  void _initializeCollectionRefs() {
    _planificationsRef = _firestore.collection('planifications');
  }

  // Écouteur des changements d'état d'authentification
  void _initializeUserListener() {
    _auth.authStateChanges().listen((auth.User? user) {
      if (user != null) {
        userId.value = user.uid;
        loadPlanifications();
      } else {
        _resetData();
      }
    });
  }

  // Méthode de création d'une nouvelle planification
  Future<bool> createPlanification({
    required String type,
    required double amount,
    required DateTime startDate,
    required String frequency,
    required String phoneReceive,
    String description = '',
    double targetAmount = 0.0,
  }) async {
    try {
      isLoading(true);

      // Validation du montant
      if (amount <= 0) {
        throw 'Le montant doit être supérieur à 0';
      }

      // Préparation des données de planification
      final planificationData = {
        'userId': userId.value,
        'type': type,
        'amount': amount,
        'phoneReceive': phoneReceive, // Ajout du phoneReceive ici
        'startDate': Timestamp.fromDate(startDate),
        'frequency': frequency,
        'description': description,
        'targetAmount': targetAmount,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'nextExecutionDate': Timestamp.fromDate(startDate),
        'completedExecutions': 0,
        'totalAmountAccumulated': 0.0,
      };

      // Sauvegarde de la planification dans Firestore
      final docRef = await _planificationsRef.add(planificationData);

      // Rechargement des planifications
      await loadPlanifications();

      isSuccessful(true);
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Chargement des planifications de l'utilisateur
  Future<void> loadPlanifications() async {
    try {
      isLoading(true);
      final snapshot = await _planificationsRef
          .where('userId', isEqualTo: userId.value)
          .where('status', isEqualTo: 'active')
          .get();

      planifications.value = snapshot.docs
          .map((doc) => {
        ...doc.data(),
        'id': doc.id // Inclusion de l'ID du document
      })
          .toList();
    } catch (e) {
      _handleError(e);
    } finally {
      isLoading(false);
    }
  }

  // Mise à jour d'une planification existante
  Future<bool> updatePlanification(String planId, Map<String, dynamic> updates) async {
    try {
      isLoading(true);
      await _planificationsRef.doc(planId).update(updates);
      await loadPlanifications();
      isSuccessful(true);
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Annulation d'une planification
  Future<bool> cancelPlanification(String planId) async {
    try {
      isLoading(true);
      await _planificationsRef.doc(planId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp()
      });
      await loadPlanifications();
      isSuccessful(true);
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Traitement de l'exécution d'une planification
  Future<bool> processPlanificationExecution(String planId, double executedAmount) async {
    try {
      isLoading(true);

      final planDoc = await _planificationsRef.doc(planId).get();
      final planData = planDoc.data();

      if (planData == null) {
        throw 'Planification non trouvée';
      }

      // Calcul de la prochaine date d'exécution
      DateTime nextExecutionDate = _calculateNextExecutionDate(
          planData['startDate'].toDate(),
          planData['frequency']
      );

      // Mise à jour de la planification
      await _planificationsRef.doc(planId).update({
        'completedExecutions': FieldValue.increment(1),
        'nextExecutionDate': Timestamp.fromDate(nextExecutionDate),
        'totalAmountAccumulated': FieldValue.increment(executedAmount),
      });

      await loadPlanifications();
      isSuccessful(true);
      return true;
    } catch (e) {
      _handleError(e);
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Calcul de la prochaine date d'exécution selon la fréquence
  DateTime _calculateNextExecutionDate(DateTime currentDate, String frequency) {
    switch (frequency) {
      case 'daily':
        return currentDate.add(Duration(days: 1));
      case 'weekly':
        return currentDate.add(Duration(days: 7));
      case 'monthly':
        return DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
      case 'quarterly':
        return DateTime(currentDate.year, currentDate.month + 3, currentDate.day);
      case 'yearly':
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
      default:
        return currentDate;
    }
  }

  // Réinitialisation des données
  void _resetData() {
    userId.value = '';
    planifications.value = [];
  }

  // Gestion des erreurs
  void _handleError(dynamic error) {
    logger.e('Erreur de Planification', error: error);

    String errorMsg = error.toString();
    errorMessage.value = errorMsg;
    isLoading(false);
    isSuccessful(false);
  }
}
