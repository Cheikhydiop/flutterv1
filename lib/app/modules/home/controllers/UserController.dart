import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';

class UserController extends GetxController {
  static UserController get to => Get.find<UserController>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
   
  RxBool isLoading = false.obs;
  RxBool isBalanceVisible = true.obs;

  // Variables observables pour stocker les données de l'utilisateur
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxList<Map<String, dynamic>> userTransactions = RxList<Map<String, dynamic>>([]);
  final RxDouble userBalance = RxDouble(0.0);

  // Getters pour accéder facilement aux données de l'utilisateur
  String get userId => currentUser.value?.id ?? '';
  String get userEmail => currentUser.value?.email ?? '';
  String get userDisplayName => currentUser.value?.displayName ?? '';
  String get userPhoneNumber => currentUser.value?.phoneNumber ?? '';
  String get userPhotoURL => currentUser.value?.photoURL ?? '';
  double get userSolde => currentUser.value?.solde ?? 0.0;
  Timestamp get userCreatedAt => currentUser.value?.createdAt ?? Timestamp.now();
  List<String> get userRoles => currentUser.value?.roles ?? [];
  String get userEtatCompte => currentUser.value?.etatCompte ?? '';

  @override
  void onInit() {
    super.onInit();
    ever(currentUser, (_) {
      update();
    });
  }

  Future<void> initializeUser(String userId) async {
    try {
      isLoading.value = true;
      await loadAndShareUserData(userId);
    } catch (e) {
      print("Erreur lors de l'initialisation de l'utilisateur: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAndShareUserData(String userId) async {
    try {
      isLoading.value = true;

      // Fetching user data from Firestore
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        // Assuming the Firestore document contains fields matching the UserModel structure
        var userData = userDoc.data() as Map<String, dynamic>;
        currentUser.value = UserModel.fromMap(userData, id: ''); // Assuming UserModel has a `fromMap` method
        userBalance.value = currentUser.value?.solde ?? 0.0;

        print("=== Données utilisateur chargées avec succès ===");
        print("ID: ${currentUser.value?.uid}");
        print("Email: ${currentUser.value?.email}");
        print("Nom d'affichage: ${currentUser.value?.displayName}");
        print("Numéro de téléphone: ${currentUser.value?.phoneNumber}");
        print("Photo URL: ${currentUser.value?.photoURL}");
        print("Solde: ${currentUser.value?.solde}");
        print("Créé le: ${currentUser.value?.createdAt}");
        print("Roles: ${currentUser.value?.roles.join(', ')}");
        print("État du compte: ${currentUser.value?.etatCompte}");

        update();
      } else {
        Get.snackbar("Erreur", "Utilisateur non trouvé.");
      }
    } catch (e) {
      print("Erreur lors du chargement des données: $e");
      Get.snackbar(
        "Erreur",
        "Une erreur est survenue lors du chargement des données: $e",
        duration: const Duration(seconds: 3)
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Méthode pour mettre à jour le solde de l'utilisateur
  Future<void> updateUserBalance(double newBalance) async {
    try {
      if (currentUser.value?.id != null) {
        await _firestore.collection('users').doc(currentUser.value!.id).update({
          'solde': newBalance,
          'updatedAt': Timestamp.now(),
        });
        userBalance.value = newBalance;
        await refreshUserData();
      }
    } catch (e) {
      print("Erreur lors de la mise à jour du solde: $e");
      Get.snackbar("Erreur", "Impossible de mettre à jour le solde");
    }
  }

  Future<void> refreshUserData() async {
    if (currentUser.value?.id != null) {
      await loadAndShareUserData(currentUser.value!.id);
    }
  }

  // Méthode pour alterner la visibilité du solde
  void toggleBalanceVisibility() {
    isBalanceVisible.value = !isBalanceVisible.value;
  }

  void clearUserData() {
    currentUser.value = null;
    userTransactions.clear();
    userBalance.value = 0.0;
  }
}



