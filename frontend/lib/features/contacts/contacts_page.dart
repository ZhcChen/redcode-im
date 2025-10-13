import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('联系人'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: const Center(child: Text('联系人页面（待接入业务逻辑）')),
    );
  }
}
