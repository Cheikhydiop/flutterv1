import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app/models/user_model.dart';
import 'app/modules/home/controllers/UserController.dart';
import 'app/modules/home/controllers/auth_controller.dart';
import 'app/modules/home/controllers/ScheduledTransferController.dart'; // Assurez-vous d'importer ce contrôleur
import 'app/routes/app_pages.dart';
import 'app/models/transaction_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialisation des contrôleurs
  Get.put(AuthController());
  Get.put(UserController());
  Get.put(ScheduledTransferController()); // Ajout du contrôleur de transfert planifié

  // Gestion de l'authentification
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    final userController = Get.find<UserController>();

    if (user != null) {
      print("Utilisateur connecté: ${user.uid}");
      await userController.loadAndShareUserData(user.uid);
    } else {
      print("Utilisateur déconnecté");
      userController.clearUserData();
    }
  });

  runApp(
    GetMaterialApp(
      title: "MoneyTransfer",
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Obx(() {
          final isLoading = Get.find<UserController>().isLoading.value;
          return Stack(
            children: [
              child ?? const SizedBox(),
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          );
        });
      },
    ),
  );
}