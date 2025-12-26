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
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
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
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Speaking Indicator Ripple
            if (participant.isSpeaking && isConnected)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    width: 3,
                  ),
                ),
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
        Text(
          isCurrentUser ? '${participant.displayName} (You)' : participant.displayName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            color: isConnected ? null : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
