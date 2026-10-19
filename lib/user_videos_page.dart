import 'package:flutter/material.dart';

import 'user_videos_grid.dart';

/// Opens when the user taps the "Videos" option on a profile.
/// Shows all published videos of that one user.
class UserVideosPage extends StatelessWidget {
  final String userId;
  final bool isOwner;
  final VoidCallback? onUpload;
  final VoidCallback? onManage;

  const UserVideosPage({
    super.key,
    required this.userId,
    this.isOwner = false,
    this.onUpload,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? 'My Videos' : 'Videos'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: UserVideosGrid(
          userId: userId,
          isOwner: isOwner,
          onUpload: onUpload,
          onManage: onManage,
        ),
      ),
    );
  }
}
