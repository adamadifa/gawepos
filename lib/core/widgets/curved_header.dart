import 'package:flutter/material.dart';
import '../constants/constants.dart';

/// Header widget dengan gradient Indigo Blue dan potongan diagonal bawah (lurus).
class CurvedHeader extends StatelessWidget {
  final double height;
  final Widget? child;
  const CurvedHeader({
    super.key,
    this.height = 200.0,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: DiagonalClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.primaryColor,
              AppConstants.primaryDarkColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Potongan diagonal lurus: sudut kiri bawah penuh, sudut kanan bawah 40px lebih tinggi.
class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Alias untuk backward compatibility
class CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Alias untuk backward compatibility (tidak lagi dipakai di halaman)
class WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
