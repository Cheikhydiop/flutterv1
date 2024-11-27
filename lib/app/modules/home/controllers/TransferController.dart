import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:get/get.dart';
import '../../../models/transaction_model.dart';

/// Contrôleur principal pour la gestion des transferts
class TransferController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Variables observables
  final Rx<String> userId = Rx<String>('');
  final Rx<String> userEmail = Rx<String>('');
  final Rx<String> userDisplayName = Rx<String>('');
  final Rx<String> userPhoneNumber = Rx<String>('');
  final Rx<String> userPhotoURL = Rx<String>('');
  final Rx<double> userSolde = Rx<double>(0.0);
  final Rx<Timestamp> userCreatedAt = Rx<Timestamp>(Timestamp.now());
  final RxList<String> userRoles = RxList<String>([]);
  final Rx<String> userEtatCompte = Rx<String>('');

  RxBool isLoading = false.obs;
  RxString errorMessage = ''.obs;
  Rx<UserDetails?> currentUser = Rx<UserDetails?>(null);

  // Collection references
  late final CollectionReference<Map<String, dynamic>> _usersRef;
  late final CollectionReference<Map<String, dynamic>> _transactionsRef;

  @override
  void onInit() {
    super.onInit();
    _initializeCollectionRefs();
    _initializeUserListener();
  }

  void _initializeCollectionRefs() {
    _usersRef = _firestore.collection('users');
    _transactionsRef = _firestore.collection('transactions');
  }

  void _initializeUserListener() {
    _auth.authStateChanges().listen((auth.User? user) async {
      if (user != null) {
        try {
          await _loadUserDetails(user);
        } catch (e) {
          _handleError(e);
        }
      } else {
        _handleSignOut();
      }
    });
  }

  Future<void> _loadUserDetails(auth.User user) async {
    try {
      final userDoc = await _usersRef.doc(user.uid).get();
      
      if (!userDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Utilisateur non trouvé dans la base de données.',
        );
      }

      currentUser.value = await UserDetails.fromFirebaseUser(user);
      if (currentUser.value != null) {
        _updateUserDataFromDetails(currentUser.value!);
        print("UserDetails chargés avec succès: ${currentUser.value}");
      }
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<bool> performTransfer({
    required double amount,
    String? receiverPhoneNumber,
    String description = '',
  }) async {
    isLoading(true);
    errorMessage('');

    try {
      // Validation initiale
      if (!_validateTransferPrerequisites(amount)) {
        return false;
      }

      // Recherche et validation du destinataire
      final receiver = await _findAndValidateReceiver(receiverPhoneNumber);
      if (receiver == null) {
        return false;
      }

      // Exécution du transfert
      await _executeTransfer(
        amount: amount,
        receiverId: receiver.id,
        receiverName: receiver.name,
        description: description,
      );

      return true;
    } catch (e) {
      if (e is TransferException) {
        errorMessage(e.message);
      } else {
        _handleError(e);
      }
      return false;
    } finally {
      isLoading(false);
    }
  }

  bool _validateTransferPrerequisites(double amount) {
    if (currentUser.value == null || !currentUser.value!.isActive) {
      throw TransferException(
        'Votre compte n\'est pas actif',
        TransferErrorType.unauthorized,
      );
    }

    if (amount <= 0) {
      throw TransferException(
        'Le montant du transfert doit être supérieur à 0',
        TransferErrorType.invalidAmount,
      );
    }

    if (amount > userSolde.value) {
      throw TransferException(
        'Solde insuffisant pour effectuer ce transfert',
        TransferErrorType.insufficientFunds,
      );
    }

    return true;
  }

  Future<ReceiverInfo?> _findAndValidateReceiver(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw TransferException(
        'Numéro de téléphone du destinataire requis',
        TransferErrorType.invalidReceiver,
      );
    }

    if (phoneNumber == userPhoneNumber.value) {
      throw TransferException(
        'Impossible de transférer vers votre propre compte',
        TransferErrorType.invalidReceiver,
      );
    }

    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    try {
      final receiverQuery = await _usersRef
          .where('phoneNumber', isEqualTo: normalizedPhone)
          .limit(1)
          .get();

      if (receiverQuery.docs.isEmpty) {
        throw TransferException(
          'Aucun compte trouvé avec ce numéro',
          TransferErrorType.receiverNotFound,
        );
      }

      final receiverDoc = receiverQuery.docs.first;
      final data = receiverDoc.data();

      if (data['etatCompte'] != 'Actif') {
        throw TransferException(
          'Le compte du destinataire n\'est pas actif',
          TransferErrorType.receiverInactive,
        );
      }

      return ReceiverInfo(
        id: receiverDoc.id,
        name: data['displayName'] ?? 'Inconnu',
      );
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
      return null;
    }
  }

  Future<void> _executeTransfer({
    required double amount,
    required String receiverId,
    required String receiverName,
    required String description,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // Get sender's current data
      final senderDoc = await transaction.get(_usersRef.doc(userId.value));
      final senderBalance = (senderDoc.data()?['solde'] as num?)?.toDouble() ?? 0.0;

      // Verify sender's balance again in transaction
      if (senderBalance < amount) {
        throw TransferException(
          'Solde insuffisant pour effectuer ce transfert',
          TransferErrorType.insufficientFunds,
        );
      }

      // Get receiver's data
      final receiverDoc = await transaction.get(_usersRef.doc(receiverId));
      if (!receiverDoc.exists) {
        throw TransferException(
          'Compte destinataire introuvable',
          TransferErrorType.receiverNotFound,
        );
      }

      // Create transaction record
      final transactionDoc = _transactionsRef.doc();
      final transactionData = {
        'senderId': userId.value,
        'senderName': userDisplayName.value,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'amount': amount,
        'description': description,
        'type': 'transfer',
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Update balances and create transaction record
      transaction.update(_usersRef.doc(userId.value), {
        'solde': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(_usersRef.doc(receiverId), {
        'solde': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(transactionDoc, transactionData);
    });

    // Update local balance
    userSolde.value -= amount;
  }

  void _handleFirebaseError(FirebaseException e) {
    print('Firebase Error: ${e.code} - ${e.message}');
    switch (e.code) {
      case 'permission-denied':
        errorMessage('Opération non autorisée');
        break;
      case 'not-found':
        errorMessage('Document non trouvé');
        break;
      case 'already-exists':
        errorMessage('Document existe déjà');
        break;
      case 'failed-precondition':
        if (e.message?.contains('index') == true) {
          final indexUrl = _extractIndexUrl(e.message!);
          errorMessage('Configuration de base de données requise. URL: $indexUrl');
        } else {
          errorMessage('Opération impossible dans l\'état actuel');
        }
        break;
      default:
        errorMessage('Erreur: ${e.message}');
    }
  }

  String _extractIndexUrl(String errorMessage) {
    final urlRegex = RegExp(r'https:\/\/console\.firebase\.google\.com[^\s]+');
    final match = urlRegex.firstMatch(errorMessage);
    return match?.group(0) ?? '';
  }

  void _handleSignOut() {
    currentUser.value = null;
    clearUserData();
  }

  void _handleError(dynamic error) {
    print('Error: $error');
    errorMessage('Une erreur inattendue s\'est produite');
    if (error is! TransferException) {
      currentUser.value = null;
      clearUserData();
    }
  }

  void _updateUserDataFromDetails(UserDetails details) {
    userId.value = details.uid;
    userEmail.value = details.email;
    userDisplayName.value = details.displayName;
    userPhoneNumber.value = details.phoneNumber;
    userPhotoURL.value = details.photoURL ?? '';
    userSolde.value = details.solde;
    userCreatedAt.value = Timestamp.fromDate(details.createdAt);
    userRoles.value = details.roles;
    userEtatCompte.value = details.etatCompte;
  }

  void clearUserData() {
    userId.value = '';
    userEmail.value = '';
    userDisplayName.value = '';
    userPhoneNumber.value = '';
    userPhotoURL.value = '';
    userSolde.value = 0.0;
    userCreatedAt.value = Timestamp.now();
    userRoles.clear();
    userEtatCompte.value = '';
  }
}

class UserDetails {
  final String uid;
  final String email;
  final String displayName;
  final String phoneNumber;
  final String? photoURL;
  final double solde;
  final DateTime createdAt;
  final List<String> roles;
  final String etatCompte;
  final bool isActive;

  const UserDetails({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    this.photoURL,
    required this.solde,
    required this.createdAt,
    required this.roles,
    required this.etatCompte,
    required this.isActive,
  });

  static Future<UserDetails> fromFirebaseUser(auth.User user) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Utilisateur non trouvé dans la collection',
      );
    }

    final data = userDoc.data() as Map<String, dynamic>;

    return UserDetails(
      uid: user.uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoURL: data['photoURL'],
      solde: (data['solde'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      roles: List<String>.from(data['roles'] ?? []),
      etatCompte: data['etatCompte'] ?? 'Inactif',
      isActive: data['etatCompte'] == 'Actif',
    );
  }

  @override
  String toString() => 'UserDetails(uid: $uid, email: $email, '
      'displayName: $displayName, phoneNumber: $phoneNumber, '
      'solde: $solde, createdAt: $createdAt, roles: $roles, '
      'etatCompte: $etatCompte, isActive: $isActive)';
}

class ReceiverInfo {
  final String id;
  final String name;

  const ReceiverInfo({
    required this.id,
    required this.name,
  });
}

class TransferException implements Exception {
  final String message;
  final TransferErrorType type;

  const TransferException(this.message, this.type);

  @override
  String toString() => 'TransferException: $message (Type: $type)';
}

enum TransferErrorType {
  insufficientFunds,
  receiverNotFound,
  senderNotFound,
  unauthorized,
  invalidAmount,
  invalidReceiver,
  receiverInactive,
  unknown,
}