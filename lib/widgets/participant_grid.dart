import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/participant_model.dart';

class ParticipantGrid extends ConsumerWidget {
  final List<ParticipantModel> participants;
  final String currentUserId;
  final ScrollController? scrollController;

  const ParticipantGrid({
    super.key,
    required this.participants,
    required this.currentUserId,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2;
        final childAspectRatio = width >= 600 ? 0.85 : 0.80;

        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participant = participants[index];
            return _ParticipantTile(
              participant: participant,
              isCurrentUser: participant.uid == currentUserId,
            );
          },
        );
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final ParticipantModel participant;
  final bool isCurrentUser;

  const _ParticipantTile({
    required this.participant,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = participant.isConnected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Speaking Indicator with Pulsing Animation
            if (participant.isSpeaking && isConnected)
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                curve: Curves.easeInOut,
                onEnd: () {
                  // Loop animation
                },
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.9),
                          width: 4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
                border: isConnected 
                  ? null 
                  : Border.all(color: theme.colorScheme.error, width: 2),
                image: participant.avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(participant.avatarUrl!),
                        fit: BoxFit.cover,
                        colorFilter: isConnected
                            ? null
                            : const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.saturation,
                              ),
                      )
                    : null,
              ),
              child: participant.avatarUrl == null
                  ? Icon(
                      Icons.person,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),

            // Host Badge
            if (participant.isHost)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),

            // Mute/Offline Indicator
            if (!isConnected)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            isCurrentUser ? '${participant.displayName} (You)' : participant.displayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              color: isConnected ? null : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
