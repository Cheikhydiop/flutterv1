import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/ScheduledTransferController.dart';

class TransferPlanifierView extends StatelessWidget {
  final ScheduledTransferController controller = Get.find<ScheduledTransferController>();

  // Form controllers
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController targetAmountController = TextEditingController();
  final TextEditingController phoneReceiveController = TextEditingController();

  // Local state for date selection
  final Rx<DateTime?> selectedDate = Rx<DateTime?>(null);
  final Rx<String?> selectedType = Rx<String?>(null);
  final Rx<String?> selectedFrequency = Rx<String?>(null);

  TransferPlanifierView({super.key});

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != selectedDate.value) {
      selectedDate.value = picked;
    }
  }

  Future<void> _handleSubmit() async {
    // Validate inputs
    if (selectedDate.value == null) {
      Get.snackbar('Erreur', 'Veuillez sélectionner une date', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (selectedType.value == null) {
      Get.snackbar('Erreur', 'Veuillez sélectionner un type de planification', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (selectedFrequency.value == null) {
      Get.snackbar('Erreur', 'Veuillez sélectionner une fréquence', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final double? amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      Get.snackbar('Erreur', 'Montant invalide', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Ensure a default empty string for phone number if not provided
    final String phoneReceive = phoneReceiveController.text.trim();

    final double targetAmount = double.tryParse(targetAmountController.text.replaceAll(',', '.')) ?? 0.0;

    try {
      bool success = await controller.createPlanification(
        type: selectedType.value!,
        amount: amount,
        startDate: selectedDate.value!,
        frequency: selectedFrequency.value!,
        description: descriptionController.text,
        targetAmount: targetAmount,
        phoneReceive: phoneReceive, // Now always a string
      );

      if (success) {
        Get.snackbar('Succès', 'Planification créée avec succès', backgroundColor: Colors.green, colorText: Colors.white);
        _resetForm();
      }
    } catch (e) {
      Get.snackbar('Erreur', controller.errorMessage.value, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _resetForm() {
    amountController.clear();
    descriptionController.clear();
    targetAmountController.clear();
    phoneReceiveController.clear();
    selectedDate.value = null;
    selectedType.value = null;
    selectedFrequency.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une Planification'),
        centerTitle: true,
      ),
      body: Obx(() => SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant cible (Optionnel)',
                prefixIcon: Icon(Icons.tablet),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneReceiveController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone du destinataire (Optionnel)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: selectedType.value,
              isExpanded: true,
              items: controller.planificationTypes
                  .map((type) => DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!)
              ))
                  .toList(),
              onChanged: (value) => selectedType.value = value,
              hint: const Text('Sélectionnez un type'),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: selectedFrequency.value,
              isExpanded: true,
              items: controller.frequencies
                  .map((freq) => DropdownMenuItem(
                  value: freq['value'],
                  child: Text(freq['label']!)
              ))
                  .toList(),
              onChanged: (value) => selectedFrequency.value = value,
              hint: const Text('Sélectionnez une fréquence'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('Sélectionnez une date'),
                  ),
                ),
                const SizedBox(width: 16),
                Obx(() => Text(
                  selectedDate.value == null
                      ? 'Aucune date sélectionnée'
                      : DateFormat('dd/MM/yyyy').format(selectedDate.value!),
                )),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: controller.isLoading.value ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: controller.isLoading.value
                  ? const CircularProgressIndicator()
                  : const Text(
                'Créer Planification',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      )),
    );
  }
}