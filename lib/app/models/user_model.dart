import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String photoURL;
  final String etatCompte;
  final List<String> roles;
  final double solde;
  final String uid;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Map<String, dynamic>? additionalData; // Ajouté ce champ

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.photoURL,
    required this.etatCompte,
    required this.roles,
    required this.solde,
    required this.uid,
    required this.createdAt,
    required this.updatedAt,
    this.additionalData, // Ajouté ce paramètre
  });

  // Convertir une instance de UserModel en un map compatible Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'etatCompte': etatCompte,
      'roles': roles,
      'solde': solde,
      'uid': uid,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'additionalData': additionalData, // Champ supplémentaire
    };
  }

  // Convertir un document Firestore en une instance de UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc, {required String id}) {
    final data = doc.data() as Map<String, dynamic>;

    // Extraire les champs connus
    Map<String, dynamic> additionalFields = Map.from(data);

    // Retirer les champs connus de additionalFields
    ['id', 'displayName', 'email', 'phoneNumber', 'photoURL',
     'etatCompte', 'roles', 'solde', 'uid', 'createdAt', 'updatedAt']
        .forEach(additionalFields.remove);

    return UserModel(
      id: data['id'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoURL: data['photoURL'] ?? '',
      etatCompte: data['etatCompte'] ?? '',
      roles: List<String>.from(data['roles'] ?? []),
      solde: data['solde']?.toDouble() ?? 0.0,
      uid: data['uid'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      additionalData: additionalFields.isNotEmpty ? additionalFields : null, // Stocker les champs supplémentaires
    );
  }

  // Méthode pour convertir un simple Map en un UserModel (utile pour des données non Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map, {required String id}) {
    return UserModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      photoURL: map['photoURL'] ?? '',
      etatCompte: map['etatCompte'] ?? '',
      roles: List<String>.from(map['roles'] ?? []),
      solde: map['solde']?.toDouble() ?? 0.0,
      uid: map['uid'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      additionalData: map['additionalData'],
    );
  }
}
