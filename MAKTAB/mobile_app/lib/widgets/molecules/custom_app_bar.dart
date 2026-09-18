import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/config/app_colors.dart';

/// Unified, gradient-backed AppBar used throughout the app.
///
/// Features:
/// - Teal→dark-teal gradient background (matches brand)
/// - White bold title — never clips; uses FittedBox to scale down if too long
/// - Gold back-arrow icon (automatic when Navigator has a route to pop)
/// - Optional [actions] row
/// - Optional [bottom] PreferredSizeWidget (e.g. a TabBar)
/// - Optional [subtitle] displayed under the title in smaller text
/// - [showBackButton] can be forced to false for root screens
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && Navigator.canPop(context);

    return AppBar(
      // Transparent so flexibleSpace gradient shows through
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: canPop ? 0 : 16,
      automaticallyImplyLeading: false,

      // Gradient background
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      ),

      // Back button — gold, consistent with brand
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.goldAccent, size: 20),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            )
          : null,

      // Title — FittedBox shrinks text if it's too wide; never overflows
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (_, constraints) => ConstrainedBox(
              // Cap width so actions don't get pushed off screen
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : double.infinity,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),

      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}