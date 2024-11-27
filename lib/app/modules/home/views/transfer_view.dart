import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/TransferController.dart';
import '../controllers/UserController.dart';
import '../controllers/auth_controller.dart';
import 'TransferPlanifier_View.dart';


class BalanceDisplay extends StatelessWidget {
  final UserController userController = Get.find<UserController>();


  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final solde = userController.userSolde;
       print("Solde actuel : $solde"); 
      
      return Card(
        elevation: 3,
        
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, 
                       color: Theme.of(context).primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Votre solde actuel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                '${solde?.toStringAsFixed(0) ?? "0"} FCFA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),



              if (solde != null && solde < 1000)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Solde faible',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}


class TransferView extends StatelessWidget {
  final TransferController transferController = Get.put(TransferController());
  final formKey = GlobalKey<FormState>();
  
  final TextEditingController receiverPhoneNumberController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  TransferView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transfert d\'argent'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(() => transferController.currentUser.value == null
        ? Center(child: CircularProgressIndicator())
        : _buildTransferForm(context)),
    );
  }

 Widget _buildTransferForm(BuildContext context) {
  return SafeArea(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBalanceDisplay(),
              SizedBox(height: 24),
              _buildPhoneNumberField(),
              SizedBox(height: 16),
              _buildAmountField(context),
              SizedBox(height: 16),
              _buildDescriptionField(),
              SizedBox(height: 24),
              _buildTransferButton(context),
              SizedBox(height: 16),
              _buildErrorMessage(),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Get.to(() => TransferPlanifierView());
                },
                child: Text(
                  'Planifier un transfert',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}




  

  Widget _buildBalanceDisplay() {
    return Obx(() => Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Solde disponible',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${transferController.userSolde.value.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildPhoneNumberField() {
    return TextFormField(
      controller: receiverPhoneNumberController,
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone du destinataire',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un numéro de téléphone';
        }
        if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(value)) {
          return 'Format de numéro invalide';
        }
        // Vérifie que le numéro n'est pas celui de l'utilisateur actuel
        if (value.replaceAll(RegExp(r'\D'), '') == 
            transferController.userPhoneNumber.value.replaceAll(RegExp(r'\D'), '')) {
          return 'Vous ne pouvez pas transférer à votre propre numéro';
        }
        return null;
      },
    );
  }

  Widget _buildAmountField(BuildContext context) {
    return TextFormField(
      controller: amountController,
      decoration: InputDecoration(
        labelText: 'Montant',
        prefixIcon: Icon(Icons.monetization_on),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixText: 'FCFA',
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer un montant';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Veuillez entrer un montant valide';
        }
        if (amount < 100) {
          return 'Le montant minimum est de 100 FCFA';
        }
        if (amount > transferController.userSolde.value) {
          return 'Solde insuffisant';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: descriptionController,
      decoration: InputDecoration(
        labelText: 'Description (optionnel)',
        prefixIcon: Icon(Icons.description),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      maxLines: 2,
      maxLength: 100,
    );
  }

  Widget _buildTransferButton(BuildContext context) {
    return Obx(() {
      final isActive = transferController.userEtatCompte.value.toLowerCase() == 'actif';
      return ElevatedButton(
        onPressed: !isActive || transferController.isLoading.value 
          ? null 
          : () => _handleTransfer(),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: transferController.isLoading.value
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Effectuer le transfert',
                style: TextStyle(fontSize: 16),
              ),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.grey,
          foregroundColor: Colors.white,
        ),
      );
    });
  }

  Widget _buildErrorMessage() {
    return Obx(() => transferController.errorMessage.value.isNotEmpty
      ? Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            transferController.errorMessage.value,
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        )
      : SizedBox.shrink());
  }

  Future<void> _handleTransfer() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final amount = double.tryParse(amountController.text) ?? 0;
    final success = await transferController.performTransfer(
      amount: amount,
      receiverPhoneNumber: receiverPhoneNumberController.text,
      description: descriptionController.text.trim(),
    );

    if (success) {
      // Efface les champs du formulaire
      receiverPhoneNumberController.clear();
      amountController.clear();
      descriptionController.clear();

      Get.snackbar(
        'Succès',
        'Transfert effectué avec succès',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      );
    }
  }

  void dispose() {
    receiverPhoneNumberController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }
}