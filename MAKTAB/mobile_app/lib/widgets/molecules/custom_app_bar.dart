import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18),
          maxLines: 1,
          softWrap: false,
        ),
      ),
      titleSpacing: 4,
      centerTitle: false,
      backgroundColor: const Color(0xFF004D40),
      automaticallyImplyLeading: showBackButton,
      iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
      leading: (showBackButton && Navigator.canPop(context))
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
              onPressed: () => context.pop(),
            )
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}