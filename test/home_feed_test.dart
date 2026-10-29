import 'package:content/app/router.dart';
import 'package:content/features/content/content_api.dart';
import 'package:content/features/content/home_feed.dart';
import 'package:content/features/content/media_view.dart';
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Finder _post(String caption) =>
    find.byWidgetPredicate((w) => w is FeedPost && w.post.caption == caption);

final _feed = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// Scrolls the feed (lazily built) until [finder] is on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: _feed.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home shows the stories tray and the feed', (tester) async {
    await pumpApp(tester);
    expect(find.byType(StoriesTray), findsOneWidget);
    expect(find.byType(FeedPost), findsWidgets);
  });

  testWidgets('double-tapping a post likes it', (tester) async {
    await pumpApp(tester);
    final post = _post('Morning stretch routine');
    await _reveal(tester, post);
    final id = tester.widget<FeedPost>(post).post.id;
    final before = tester.widget<FeedPost>(post).post.likes;
    final heart = find.descendant(
      of: find.byKey(ValueKey('like-$id')),
      matching: find.byIcon(Icons.favorite),
    );
    expect(heart, findsNothing);

    final media = find.descendant(of: post, matching: find.byType(AspectRatio));
    await tester.tap(media);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(media);
    await tester.pumpAndSettle();

    expect(heart, findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(ValueKey('likes-$id'))).data,
      '${before + 1} ${before + 1 == 1 ? 'like' : 'likes'}',
    );
  });

  testWidgets('following a suggested creator flips the button', (tester) async {
    await pumpApp(tester);
    final follow = find.byKey(const ValueKey('suggest-follow-amani'));
    await _reveal(tester, follow);
    expect(
      find.descendant(of: follow, matching: find.text('Follow')),
      findsOneWidget,
    );
    await tester.tap(follow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: follow, matching: find.text('Following')),
      findsOneWidget,
    );
  });

  testWidgets('a liked post keeps its like after scrolling away and back', (
    tester,
  ) async {
    await pumpApp(tester);
    final free = _post('Morning stretch routine');
    await _reveal(tester, free);
    final post = tester.widget<FeedPost>(free).post;
    expect(post.locked, isFalse);
    final id = post.id;
    final heart = find.descendant(
      of: find.byKey(ValueKey('like-$id')),
      matching: find.byIcon(Icons.favorite),
    );
    await _reveal(tester, find.byKey(ValueKey('like-$id')));
    await tester.tap(find.byKey(ValueKey('like-$id')));
    await tester.pumpAndSettle();
    expect(heart, findsOneWidget);

    for (var i = 0; i < 8; i++) {
      await tester.drag(_feed.first, const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('like-$id')), findsNothing);
    for (var i = 0; i < 8; i++) {
      await tester.drag(_feed.first, const Offset(0, 600));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(heart, findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(ValueKey('likes-$id'))).data,
      '${post.likes + 1} ${post.likes + 1 == 1 ? 'like' : 'likes'}',
    );
  });

  testWidgets('a locked post shows LockedMedia and never loads its media', (
    tester,
  ) async {
    await pumpApp(tester);
    final locked = find.byWidgetPredicate(
      (w) => w is FeedPost && w.post.caption == 'Full routine, uncut',
    );
    await _reveal(tester, locked);
    expect(tester.widget<FeedPost>(locked).post.locked, isTrue);
    final id = tester.widget<FeedPost>(locked).post.id;
    final scope = find.byKey(ValueKey('feed-post-$id'));
    expect(
      find.descendant(of: scope, matching: find.byType(LockedMedia)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scope, matching: find.byType(MediaView)),
      findsNothing,
    );
  });

  testWidgets('the lead is the first unlocked post, not a locked one', (
    tester,
  ) async {
    await pumpApp(tester);
    final lead = tester.widgetList<FeedPost>(find.byType(FeedPost)).first;
    expect(lead.lead, isTrue);
    expect(lead.post.locked, isFalse);
    expect(lead.post.caption, isNot('Pilau, my way'));
  });

  testWidgets("a post's menu opens above the tab bar", (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    // Under the floating tab bar this tap would land on the bar instead.
    await tester.tap(find.text('View post'));
    await tester.pumpAndSettle();
    expect(find.text('Post'), findsOneWidget);
  });

  testWidgets('a creator room follows the third post and its Follow flips', (
    tester,
  ) async {
    await pumpApp(tester);
    final follow = find.byKey(const ValueKey('suggest-follow-zuri'));
    // Positions in feed coordinates, so they compare across scrolls.
    double at(Offset o) =>
        o.dy + tester.state<ScrollableState>(_feed.first).position.pixels;
    // The lead is post one, so the first room sits right under post three.
    final third = _post('30-day programme');
    final fourth = _post('Morning stretch routine');
    await _reveal(tester, third);
    final thirdEnd = at(tester.getBottomLeft(third));
    await _reveal(tester, follow);
    final room = at(tester.getTopLeft(follow));
    expect(room, greaterThan(thirdEnd));
    expect(
      find.descendant(of: follow, matching: find.text('Follow')),
      findsOneWidget,
    );
    await tester.tap(follow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: follow, matching: find.text('Following')),
      findsOneWidget,
    );
    await _reveal(tester, fourth);
    expect(room, lessThan(at(tester.getTopLeft(fourth))));
  });

  testWidgets('a browse chip opens search with its category selected', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('browse-Fitness')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('discover-search')), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Fitness'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Music'))
          .selected,
      isFalse,
    );
  });

  testWidgets('an empty feed with no rooms to offer shows its empty state', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        feedProvider.overrideWith((_) async => <Post>[]),
        discoveryProvider.overrideWith((_, _) async => throw 'offline'),
      ],
    );
    expect(find.text('Your feed is quiet'), findsOneWidget);
  });

  testWidgets('following from a room updates the Following tab', (
    tester,
  ) async {
    Finder tab(String label) => find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text(label),
    );
    await pumpApp(tester);
    // Open Following first, so it stays mounted with its old list.
    await tester.tap(tab('Following'));
    await tester.pumpAndSettle();
    expect(find.text('@zuri'), findsNothing);
    await tester.tap(tab('Discover'));
    await tester.pumpAndSettle();

    final follow = find.byKey(const ValueKey('suggest-follow-zuri'));
    await _reveal(tester, follow);
    await tester.tap(follow);
    await tester.pumpAndSettle();
    await tester.tap(tab('Following'));
    await tester.pumpAndSettle();

    expect(find.text('@zuri'), findsWidgets);
  });

  testWidgets('an empty feed shows creator rooms instead of failing', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [feedProvider.overrideWith((_) async => <Post>[])],
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FeedPost), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => '${w.key}'.contains('suggest-follow-'),
      ),
      findsWidgets,
    );
  });
}
