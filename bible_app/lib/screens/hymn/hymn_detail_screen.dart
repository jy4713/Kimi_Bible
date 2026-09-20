import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../models/hymn_entry.dart';
import '../../models/source_info.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/hymn_repository.dart';
import '../../widgets/html_content.dart';

class HymnDetailScreen extends StatefulWidget {
  final SourceInfo source;
  final int initialChapter;
  final List<HymnEntry> allHymns;

  const HymnDetailScreen({
    super.key,
    required this.source,
    required this.initialChapter,
    required this.allHymns,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late TabController _tabController;
  late int _currentIndex;

  /// True while the sheet-music viewer is zoomed in — the surrounding
  /// PageView must not turn pages while the user pans a zoomed image.
  bool _swipeBlocked = false;

  /// Sources without a .cmp companion (e.g. 교독문) get a lyrics-only UI:
  /// no 악보/가사 tabs, no sheet-music page view.
  bool get hasSheetMusic => widget.source.effectiveCompanionPath.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allHymns
        .indexWhere((h) => h.chapter == widget.initialChapter)
        .clamp(0, widget.allHymns.length - 1);
    // A SINGLE page view backs both tabs: its item builder renders either
    // the sheet-music page or the lyrics page for the current tab. Two page
    // views (one per tab) caused a stale chapter from the keep-alive bucket
    // to flash for a frame on every tab switch.
    _pageController = PageController(initialPage: _currentIndex);
    _tabController =
        TabController(length: 2, vsync: this)..addListener(_onTabAnim);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  HymnEntry get current => widget.allHymns[_currentIndex];

  bool get _showMusic => hasSheetMusic && _tab == 0;
  int _tab = 0;

  /// Rebuild once when the selected tab actually changes.
  void _onTabAnim() {
    if (_tabController.index != _tab) {
      setState(() => _tab = _tabController.index);
    }
  }

  void _onViewerScale(double scale) {
    final blocked = scale > 1.001;
    if (blocked != _swipeBlocked) {
      setState(() => _swipeBlocked = blocked);
    }
  }

  void _prev() {
    if (_currentIndex <= 0 || !_pageController.hasClients) return;
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _next() {
    if (_currentIndex >= widget.allHymns.length - 1 ||
        !_pageController.hasClients) {
      return;
    }
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings(settings.appLanguage);
    final title = hasSheetMusic
        ? '${strings.chapterLabel(current.chapter)}  ${current.plainTitle}'
        : '${current.chapter}. ${current.plainTitle}';
    final indexLabel = hasSheetMusic
        ? strings.chapterLabel(current.chapter)
        : '${current.chapter}';

    final contentView = PageView.builder(
      controller: _pageController,
      physics: _swipeBlocked ? const NeverScrollableScrollPhysics() : null,
      itemCount: widget.allHymns.length,
      onPageChanged: (i) => setState(() {
        _currentIndex = i;
        _swipeBlocked = false; // a fresh page starts un-zoomed
      }),
      itemBuilder: (_, i) => _showMusic
          ? _SheetMusicPage(
              source: widget.source,
              chapter: widget.allHymns[i].chapter,
              onZoom: _onViewerScale,
            )
          : _LyricsPage(hymn: widget.allHymns[i]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: hasSheetMusic
            ? TabBar(
                controller: _tabController,
                // Icon beside the label (not stacked) to keep the bar short.
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_outlined, size: 18),
                        const SizedBox(width: 5),
                        Text(strings.sheetMusic),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lyrics_outlined, size: 18),
                        const SizedBox(width: 5),
                        Text(strings.lyrics),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(child: contentView),
          // Bottom nav bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  IconButton.outlined(
                    onPressed: _currentIndex > 0 ? _prev : null,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        indexLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _currentIndex < widget.allHymns.length - 1
                        ? _next
                        : null,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMusicPage extends StatefulWidget {
  final SourceInfo source;
  final int chapter;

  /// Reports the viewer's current scale so the parent can disable page
  /// swiping while the image is zoomed in.
  final ValueChanged<double> onZoom;

  const _SheetMusicPage({
    required this.source,
    required this.chapter,
    required this.onZoom,
  });

  @override
  State<_SheetMusicPage> createState() => _SheetMusicPageState();
}

class _SheetMusicPageState extends State<_SheetMusicPage> {
  Uint8List? _bytes;
  bool _loading = true;
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_SheetMusicPage old) {
    super.didUpdateWidget(old);
    if (old.chapter != widget.chapter || old.source.id != widget.source.id) {
      _transform.value = Matrix4.identity();
      _loadImage();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _reportScale() =>
      widget.onZoom(_transform.value.getMaxScaleOnAxis());

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _bytes = null;
    });
    final bytes = await HymnRepository.instance.getHymnImage(
      widget.source,
      widget.chapter,
    );
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(context.watch<SettingsProvider>().appLanguage);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bytes == null) {
      return Center(child: Text(strings.cannotLoadSheetMusic));
    }
    // Fit inside the CONTENT area only (the region between the tab bar and
    // the bottom nav — the surrounding Expanded hands exactly those
    // constraints to this page). BoxFit.contain picks whichever of
    // width/height limits first, so on phones the page fills the width and on
    // wide tablet layouts it shrinks to fit the height: nothing is ever cut
    // off. Pinch-zoom and pan still work via InteractiveViewer.
    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1.0,
      maxScale: 5.0,
      onInteractionUpdate: (_) => _reportScale(),
      onInteractionEnd: (_) => _reportScale(),
      child: Center(
        child: Image.memory(_bytes!, fit: BoxFit.contain),
      ),
    );
  }
}

class _LyricsPage extends StatelessWidget {
  final HymnEntry hymn;
  const _LyricsPage({required this.hymn});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${hymn.chapter}. ${hymn.plainTitle}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          HtmlContent(html: hymn.text, fontSize: 15),
        ],
      ),
    );
  }
}
