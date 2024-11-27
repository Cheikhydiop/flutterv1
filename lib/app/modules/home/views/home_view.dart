import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:walle1_0/app/modules/home/views/transfer_view.dart';
import '../controllers/UserController.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';


class HomeView extends StatelessWidget {
  final HomeController homeController = Get.put(HomeController());
  final AuthController authController = Get.put(AuthController());
  final UserController userController = Get.find<UserController>();

  final NumberFormat currencyFormat = NumberFormat.simpleCurrency();

  HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!authController.isLoading.value && authController.currentUser.value == null) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(),
        body: Obx(() => authController.isLoading.value
            ? const Center(child: CircularProgressIndicator())
            : _buildHomeContent()),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            backgroundImage: authController.currentUser.value?.photoURL != null
                ? NetworkImage(authController.currentUser.value!.photoURL!)
                : null,
            child: authController.currentUser.value?.photoURL == null
                ? const Icon(Icons.person, color: Colors.blue)
                : null,
          ),
          const SizedBox(width: 12),
          Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour,',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                authController.currentUser.value?.displayName ?? 'Utilisateur',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          )),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.black),
          onPressed: () => authController.logout(),
        ),
      ],
    );
  }








  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Services rapides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildServicesList(),
          _buildRecentTransactions(),
        ],
      ),
    );
  }










  Widget _buildBalanceCard() {
    return Obx(() {

      
      final userSolde = userController.userSolde;
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.blue.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solde total',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                Obx(() => IconButton(
                  icon: Icon(
                    homeController.isBalanceVisible.value
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white,
                  ),
                  onPressed: () => homeController.toggleBalanceVisibility(),
                )),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() => homeController.isBalanceVisible.value
                ? Text(
                    currencyFormat.format(userSolde),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Text(
                    '••••••••••',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
            _buildUserRoleInfo(),
            const SizedBox(height: 20),
            _buildQuickActions(),
          ],
        ),
      );
    });
  }
























  Widget _buildUserRoleInfo() {
    return Obx(() {
      if (authController.currentUser.value?.roles.contains('user') == true) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Vous avez accès aux fonctionnalités utilisateur.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    });
  }













  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickAction(
          icon: Icons.add,
          label: 'Recharger',
          onTap: () {},
        ),
        _buildQuickAction(
          icon: Icons.send,
          label: 'Envoyer',
          onTap: () => Get.to(() => TransferView()),
        ),
        _buildQuickAction(
          icon: Icons.qr_code_scanner,
          label: 'Scanner',
          onTap: () {},
        ),
      ],
    );
  }












  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          _ServiceCard(icon: Icons.phone_android, label: 'Crédit\nTéléphone', color: Colors.purple),
          _ServiceCard(icon: Icons.bolt, label: 'Électricité', color: Colors.orange),
          _ServiceCard(icon: Icons.water_drop, label: 'Eau', color: Colors.blue),
          _ServiceCard(icon: Icons.tv, label: 'TV', color: Colors.red),
        ],
      ),
    );
  }













  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transactions récentes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => homeController.recentTransactions.isEmpty
              ? const Center(child: Text('Aucune transaction récente'))
              : Column(
                  children: homeController.recentTransactions
                      .map((transaction) => _TransactionItem(
                            icon: Icons.arrow_downward,
                            title: transaction.description,
                            date: DateFormat('dd/MM/yyyy HH:mm')
                                .format(transaction.date),
                            amount: currencyFormat.format(transaction.amount),
                            isCredit: true,
                          ))
                      .toList(),
                )),
        ],
      ),
    );
  }
















  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sync_alt),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Cartes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ServiceCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final String amount;
  final bool isCredit;

  const _TransactionItem({
    required this.icon,
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isCredit ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(date, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}