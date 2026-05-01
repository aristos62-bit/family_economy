import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/core/services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        // ✅ ΜΗΝ δείχνεις τίποτα μέχρι να γίνει το πρώτο check
        final bool showOffline =
            connectivity.isInitialized && connectivity.isOffline;

        return Stack(
          children: [
            child,

            if (showOffline) // ✅ εμφανίζεται μόνο όταν έχει επιβεβαιωθεί offline
              Positioned(
                top: MediaQuery.of(context).padding.top + 1,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: IgnorePointer(
                    ignoring: true,
                    child: AnimatedOpacity(
                      opacity: showOffline ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
                      child: Align(
                        alignment: Alignment.topRight, // ✅ τελείως δεξιά
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 16,
                          ), // ✅ μικρό margin από την άκρη
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min, // ✅ κλείνει στο μήκος του
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    color: Colors.orangeAccent.withValues(
                                      alpha: 0.9,
                                    ),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Off Line', // ✅ νέο μήνυμα
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                    //overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
