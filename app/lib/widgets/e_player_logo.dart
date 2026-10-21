import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Crisp, scalable E-Player logo widget powered by local SVG assets.
class EPlayerLogo extends StatelessWidget {
  const EPlayerLogo({super.key, this.height = 40, this.markOnly = false, this.lightSurface = false, this.semanticsLabel = 'E-Player'});
  final double height;
  final bool markOnly;
  final bool lightSurface;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final asset = markOnly
        ? 'assets/brand/e_player_symbol.svg'
        : lightSurface
            ? 'assets/brand/e_player_logo_light.svg'
            : 'assets/brand/e_player_logo.svg';
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: SvgPicture.asset(asset, height: height, fit: BoxFit.contain),
    );
  }
}
