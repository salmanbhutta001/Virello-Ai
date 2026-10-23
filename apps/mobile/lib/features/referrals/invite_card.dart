import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';


/// Branded invite card rendered offstage and captured as a PNG for sharing.
///
/// Visual > plain text: a friend who SEEs the Virello brand, the free-credits
/// offer and a scannable QR is far more likely to install than one who gets
/// a bare link. Fixed 900x1200 logical size for a crisp share image.
class InviteCard extends StatelessWidget {
  final String code;
  final String link;
  final String headline;
  final String subline;
  final String codeLabel;
  final String scanLabel;
  final String offerLabel;

  const InviteCard({
    super.key,
    required this.code,
    required this.link,
    required this.headline,
    required this.subline,
    required this.codeLabel,
    required this.scanLabel,
    required this.offerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 900,
      height: 1200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1035), Color(0xFF3B1154), Color(0xFF7A1E5A)],
        ),
      ),
      child: Stack(
        children: [
          // Soft decorative circles.
          Positioned(
            top: -120,
            right: -120,
            child: _glow(360, const Color(0xFFF95177).withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _glow(380, const Color(0xFF7C3AED).withValues(alpha: 0.4)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand row.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFF95177), Color(0xFFE63E63)],
                        ),
                      ),
                      child: const Center(
                        child: Text('V',
                            style: TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text('Virello',
                        style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1)),
                  ],
                ),
                const SizedBox(height: 56),
                // Offer badge.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(
                    offerLabel,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B1154)),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25),
                ),
                const SizedBox(height: 20),
                Text(
                  subline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4),
                ),
                const Spacer(),
                // QR + code row.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: QrImageView(
                        data: link,
                        version: QrVersions.auto,
                        size: 300,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 48),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          codeLabel,
                          style: TextStyle(
                              fontSize: 26,
                              color:
                                  Colors.white.withValues(alpha: 0.75)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  scanLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 12),
                Text(
                  'virello.app',
                  style: TextStyle(
                      fontSize: 26,
                      color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
