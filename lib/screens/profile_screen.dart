import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/statistics_provider.dart';
import 'top_tracks_screen.dart';
import 'admin_tab.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const Center(child: Text('User not found'));

        final isAdmin = user.isAdmin;

        if (!isAdmin) {
          return _buildContent(context, user);
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const TabBar(
                  tabs: [
                    Tab(text: 'User Info'),
                    Tab(text: 'Admin'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildContent(context, user),
                    const AdminTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'Error loading profile',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserModel user) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 32),
          const _ListeningActivitySection(),
          const SizedBox(height: 32),
          const _MostPlayedCardSection(),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinedDate = DateFormat('d MMM yyyy').format(user.createdAt);

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
            border: Border.all(
              color: theme.colorScheme.surfaceContainerHighest,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName.isNotEmpty ? user.displayName : 'Unknown User',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Joined $joinedDate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListeningActivitySection extends ConsumerWidget {
  const _ListeningActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(weeklyActivityProvider);
    final weekOffset = ref.watch(weekOffsetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Listening Activity',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref.read(weekOffsetProvider.notifier).state--,
                ),
                Text(
                  weekOffset == 0 ? 'This Week' : (weekOffset == -1 ? 'Last Week' : '$weekOffset Weeks'),
                  style: theme.textTheme.labelLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: weekOffset == 0 
                    ? null 
                    : () => ref.read(weekOffsetProvider.notifier).state++,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: activityAsync.when(
            data: (data) => LayoutBuilder(
              builder: (context, constraints) {
                if (data.days.isEmpty) {
                  return const Center(child: Text('No activity data'));
                }

                final maxMinutes = data.days
                    .map((e) => e.minutes)
                    .fold(0, (prev, curr) => curr > prev ? curr : prev);
                
                final safeMax = maxMinutes > 0 ? maxMinutes : 60; // Default scale to 1 hour if empty

                final totalSpacing = (data.days.length - 1) * 12.0;
                final availableWidth = constraints.maxWidth - totalSpacing;
                final barWidth = availableWidth / data.days.length;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.days.map((item) {
                    final heightFactor = item.minutes / safeMax;
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                         if (item.minutes > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${item.minutes}m',
                              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                            ),
                          ),
                        Flexible(
                          child: Tooltip(
                            message: '${item.date.weekday}: ${item.minutes} mins (${item.songCount} songs)',
                            triggerMode: TooltipTriggerMode.tap,
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutQuart,
                              tween: Tween(begin: 0, end: heightFactor),
                              builder: (context, value, _) {
                                return Container(
                                  width: barWidth.clamp(8.0, 30.0),
                                  height: (constraints.maxHeight - 40) * value + 1, // +1 min height
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(15), // Round bars
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _MostPlayedCardSection extends ConsumerWidget {
  const _MostPlayedCardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final topTracksAsync = ref.watch(topTracksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Most Played',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TopTracksScreen()),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        topTracksAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('No listening history yet')),
                ),
              );
            }
            final topTrack = tracks.first;
            
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias, 
              child: InkWell(
                onTap: () {
                  // Maybe play?
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Rank Badge
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '#1',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Track Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topTrack.song.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              topTrack.song.artist,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Trailing Metadata
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${topTrack.playCount} plays',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))),
          error: (e, _) => const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Error loading stats')))),
        ),
      ],
    );
  }
}
