import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../features/auth/data/auth_repository.dart';

/// Foto profil bundar; inisial bila foto tidak ada / gagal dimuat.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 40});

  final AppUser user;
  final double size;

  @override
  Widget build(BuildContext context) => NameAvatar(
    name: user.name,
    initials: user.initials,
    url: user.photoUrl,
    size: size,
  );
}

class NameAvatar extends StatelessWidget {
  const NameAvatar({
    super.key,
    required this.name,
    required this.initials,
    this.url,
    this.size = 40,
  });

  final String name;
  final String initials;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.primaryContainer,
      ),
      child: Text(
        initials,
        style: context.text.labelLarge?.copyWith(
          color: c.primary,
          fontSize: size * 0.36,
        ),
      ),
    );
    return Semantics(
      label: 'Foto $name',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
      ),
    );
  }
}
