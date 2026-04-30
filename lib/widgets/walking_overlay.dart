import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WalkingOverlay extends StatelessWidget {
  final bool visible;
  final String destinationName;
  final String finalInstruction;
  final VoidCallback onDismiss;

  const WalkingOverlay({
    super.key,
    required this.visible,
    required this.destinationName,
    required this.finalInstruction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(milliseconds: visible ? 400 : 300),
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Lottie.network(
                          // TODO: Replace with a bundled asset for production/offline use.
                          'https://assets9.lottiefiles.com/packages/lf20_gkgqj2yq.json',
                          repeat: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.directions_walk,
                              size: 120,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Heading to $destinationName',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        finalInstruction,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),
                      OutlinedButton.icon(
                        key: const ValueKey('dismissWalkingOverlay'),
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close),
                        label: const Text('Dismiss'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
