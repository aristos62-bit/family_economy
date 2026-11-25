import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/services/connectivity_service.dart';

class OfflineAppBarChip extends StatelessWidget {
  const OfflineAppBarChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        // εδώ μπορείς να κρατήσεις init check αν θες
        final show = connectivity.isInitialized && connectivity.isOffline;

        if (!show) return const SizedBox.shrink();

        return Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 14,
                color: Colors.orangeAccent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              const Text(
                'OFFLINE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
