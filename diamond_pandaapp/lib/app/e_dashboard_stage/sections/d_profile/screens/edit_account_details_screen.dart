import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../widgets/common/custom_appbar.dart';

@RoutePage()
class EditAccountDetailsScreen extends StatelessWidget {
  const EditAccountDetailsScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/icons/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(title: 'edit-account-details'),
      ),
    );
  }
}
