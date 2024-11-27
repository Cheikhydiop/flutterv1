import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetails {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final List<String> roles;
  final String etatCompte;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double solde;

  UserDetails({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.roles = const [],
    this.etatCompte = "Actif",
    DateTime? createdAt,
    DateTime? updatedAt,
    this.solde = 0.0,
  }) : 
  createdAt = createdAt ?? DateTime.now(),
  updatedAt = updatedAt ?? DateTime.now();

  factory UserDetails.fromFirebaseUser(User user) {
    return UserDetails(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber, // Inclure le numéro de téléphone
      'roles': roles,
      'etatCompte': etatCompte,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'solde': solde,
    };
  }

  // Création depuis Map
  factory UserDetails.fromMap(Map<String, dynamic> map) {
    return UserDetails(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      roles: List<String>.from(map['roles'] ?? []),
      etatCompte: map['etatCompte'] as String? ?? "Actif",
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      solde: (map['solde'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    var _userSolde = 0.0.obs; 


  final Rxn<UserDetails> currentUser = Rxn<UserDetails>();
  final isLoading = false.obs;
  var isLoggedIn = false.obs;

  void logout() {
    isLoggedIn.value = false;
    Get.offAllNamed('/login');
  }


  // Getter for userSolde
  double get userSolde => _userSolde.value;

  // Setter for userSolde (if needed)
  set userSolde(double value) {
    _userSolde.value = value;
  }
  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // Récupérer les détails de l'utilisateur à partir de Firestore
        final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        
        if (userDoc.exists) {
          // Récupérer les données de Firestore et les ajouter dans currentUser
          currentUser.value = UserDetails.fromMap(userDoc.data()!);
        } else {
          currentUser.value = UserDetails.fromFirebaseUser(firebaseUser);
        }
      } else {
        currentUser.value = null;
      }
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException(
          'L\'utilisateur a annulé la connexion Google.',
          AuthErrorType.cancelled,
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Convertir en UserDetails
        final userDetails = UserDetails.fromFirebaseUser(userCredential.user!);

        // Vérifier si l'utilisateur existe déjà dans Firestore
        final userDoc = await _firestore.collection('users').doc(userDetails.uid).get();
        
        if (!userDoc.exists) {
          // Si c'est la première connexion, demander le numéro de téléphone
          final phoneNumber = await _showPhoneNumberDialog();
          
          if (phoneNumber == null || phoneNumber.isEmpty) {
            // L'utilisateur a annulé la saisie du numéro de téléphone
            await _auth.signOut();
            throw AuthException(
              'Numéro de téléphone requis',
              AuthErrorType.cancelled,
            );
          }

          // Créer un nouvel objet UserDetails avec le numéro de téléphone
          final completeUserDetails = UserDetails(
            uid: userDetails.uid,
            email: userDetails.email,
            displayName: userDetails.displayName,
            photoURL: userDetails.photoURL,
            phoneNumber: phoneNumber,
            roles: [],
          );

          // Enregistrer les détails de l'utilisateur dans Firestore
          await _firestore.collection('users').doc(completeUserDetails.uid).set(
            completeUserDetails.toMap(),
            SetOptions(merge: true),
          );

          // Mettre à jour currentUser
          currentUser.value = completeUserDetails;
        }
        
        isLoggedIn.value = true;
        Get.offNamed('/home');
      }

    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        'Une erreur inattendue est survenue: $e',
        AuthErrorType.unknown,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> _showPhoneNumberDialog() async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return await Get.dialog<String>(
      AlertDialog(
        title: Text('Complétez votre profil'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Entrez votre numéro de téléphone',
              prefixText: '+221 ', // Code pays du Sénégal
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un numéro de téléphone';
              }
              // Validation de base du numéro de téléphone
              if (!RegExp(r'^[0-9]{9}$').hasMatch(value)) {
                return 'Numéro de téléphone invalide';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Get.back(result: null),
          ),
          ElevatedButton(
            child: Text('Confirmer'),
            onPressed: () {
              // Vérifier la validation du formulaire
              if (formKey.currentState!.validate()) {
                // Récupérer le numéro de téléphone
                final phoneNumber = '+221${phoneController.text}';
                // Fermer le dialogue et retourner le numéro de téléphone
                Get.back(result: phoneNumber);
              }
            },
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      currentUser.value = null;
    } catch (e) {
      throw AuthException(
        'Erreur lors de la déconnexion: $e',
        AuthErrorType.signOut,
      );
    }
  }

  AuthException _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return AuthException(
          'Ce compte existe déjà avec une autre méthode de connexion',
          AuthErrorType.accountExists,
        );
      case 'invalid-credential':
        return AuthException(
          'Les informations d\'identification ne sont pas valides',
          AuthErrorType.invalidCredentials,
        );
      case 'user-not-found':
        return AuthException(
          'Aucun utilisateur trouvé avec ces informations',
          AuthErrorType.unknown,
        );
      case 'wrong-password':
        return AuthException(
          'Mot de passe incorrect',
          AuthErrorType.invalidCredentials,
        );
      default:
        return AuthException(
          'Erreur d\'authentification: ${e.message}',
          AuthErrorType.unknown,
        );
    }
  }
}

enum AuthErrorType {
  network,
  cancelled,
  accountExists,
  invalidCredentials,
  signOut,
  unknown,
}

class AuthException implements Exception {
  final String message;
  final AuthErrorType errorType;

  AuthException(this.message, this.errorType);

  get type => null;
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Center(
        child: Obx(
          () => Text(
            'Bienvenue, ${Get.find<AuthController>().currentUser.value?.displayName ?? 'Invité'}',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(GetMaterialApp(
    initialBinding: BindingsBuilder(() {
      Get.put(AuthController());
    }),
    home: HomePage(),
  ));
}
