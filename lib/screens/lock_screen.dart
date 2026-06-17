import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class LockScreenWidget extends StatelessWidget {
  const LockScreenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 64, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            Text(
              'App Locked',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please enter an activation code or join a team with an active activation code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => GoRouter.of(context).go('/settings'),
              icon: const Icon(Icons.settings),
              label: Text('Go to Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
