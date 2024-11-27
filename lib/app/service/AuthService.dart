import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Connectivity _connectivity = Connectivity();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  var user = Rxn<User>();
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen((User? currentUser) {
      user.value = currentUser;
    });
  }

  /// Vérifie la connexion Internet
  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Authentification via Google avec gestion d'erreurs améliorée
  Future<UserModel> signInWithGoogle() async {
    try {
      isLoading.value = true;

      // Vérification de la connexion Internet
      if (!await _checkInternetConnection()) {
        throw AuthException(
            'Pas de connexion Internet. Veuillez vérifier votre connexion et réessayer.',
            AuthErrorType.network
        );
      }

      // Tentative de connexion Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException(
            'Processus de connexion annulé',
            AuthErrorType.cancelled
        );
      }

      // Obtention des credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AuthException(
            'Impossible d\'obtenir les tokens d\'authentification',
            AuthErrorType.credentials
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Connexion Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      // Récupération de l'ID Firebase
      String firebaseUserId = firebaseUser?.uid ?? '';

      // Vérification si l'utilisateur existe déjà dans Firestore
      final docSnapshot = await _firestore.collection('users').doc(firebaseUserId).get();
      if (!docSnapshot.exists) {
        // Si l'utilisateur n'existe pas, créez un nouvel utilisateur avec l'ID Google
        await _firestore.collection('users').doc(firebaseUserId).set({
          'id': firebaseUserId,
          'name': firebaseUser?.displayName,
          'email': firebaseUser?.email,
          'photoUrl': firebaseUser?.photoURL,
          // Ajoutez ici d'autres données nécessaires
        });
      }

      // Retourner l'utilisateur
      return UserModel.fromFirestore(docSnapshot, id: '');

    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } on PlatformException catch (e) {
      throw _handlePlatformError(e);
    } catch (e) {
      throw AuthException(
          'Une erreur inattendue est survenue: $e',
          AuthErrorType.unknown
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Gestion des erreurs Firebase
  AuthException _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return AuthException(
            'Ce compte existe déjà avec une méthode de connexion différente',
            AuthErrorType.accountExists
        );
      case 'invalid-credential':
        return AuthException(
            'Les informations d\'identification sont invalides',
            AuthErrorType.invalidCredentials
        );
      default:
        return AuthException(
            'Erreur Firebase: ${e.message}',
            AuthErrorType.firebase
        );
    }
  }

  /// Gestion des erreurs de plateforme
  AuthException _handlePlatformError(PlatformException e) {
    if (e.code == 'network_error') {
      return AuthException(
          'Erreur réseau. Veuillez vérifier votre connexion',
          AuthErrorType.network
      );
    }
    return AuthException(
        'Erreur plateforme: ${e.message}',
        AuthErrorType.platform
    );
  }

  /// Déconnexion sécurisée
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      throw AuthException(
          'Erreur lors de la déconnexion: $e',
          AuthErrorType.signOut
      );
    }
  }

  User? get currentUser => user.value;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
}

/// Types d'erreurs d'authentification
enum AuthErrorType {
  network,
  cancelled,
  credentials,
  accountExists,
  invalidCredentials,
  firebase,
  platform,
  signOut,
  unknown
}

/// Exception personnalisée pour l'authentification
class AuthException implements Exception {
  final String message;
  final AuthErrorType type;

  AuthException(this.message, this.type);

  @override
  String toString() => 'AuthException: $message';
}
