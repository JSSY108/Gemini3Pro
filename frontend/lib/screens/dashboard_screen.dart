import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grounding_models.dart';
import '../services/fact_check_service.dart';
import '../widgets/glass_action_bar.dart';
import '../widgets/source_sidebar_container.dart';
import '../widgets/verdict_pane.dart';
import '../widgets/veriscan_interactive_text.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final FactCheckService _service = FactCheckService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _sidebarScrollController = ScrollController();
  final GlobalKey _sidebarKey = GlobalKey();

  AnalysisResponse? _result;
  bool _isLoading = false;
  bool _isSidebarExpanded = true;

  // Attachments State
  List<SourceAttachment> _pendingAttachments = [];
  List<SourceAttachment> _migratedAttachments = [];
  final Map<String, GlobalKey> _chipKeys = {};

  // CHANGED: Track both active indices (for sidebar) and active support (for text)
  List<int> _activeCitationIndices = [];
  GroundingSupport? _activeSupport;

  // ===========================================================================
  //  LOGIC
  // ===========================================================================

  void _handleAddAttachment(SourceAttachment attachment) {
    setState(() {
      _pendingAttachments.add(attachment);
    });
  }

  void _handleRemoveAttachment(String id) {
    setState(() {
      _pendingAttachments.removeWhere((a) => a.id == id);
      _chipKeys.remove(id);
    });
  }

  Future<void> _handleAnalysis() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    // 1. Start Migration Animation
    if (_pendingAttachments.isNotEmpty) {
      await _animateMigration();
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _activeCitationIndices = [];
      _activeSupport = null;
    });

    final toMigrate = List<SourceAttachment>.from(_pendingAttachments);

    try {
      final result = await _service.analyzeNews(
        text: text,
        attachments: toMigrate,
      );
      setState(() {
        _result = result;
        _migratedAttachments.addAll(toMigrate);
        _pendingAttachments.clear();
        _chipKeys.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _animateMigration() async {
    final List<SourceAttachment> attachments = List.from(_pendingAttachments);
    final List<OverlayEntry> entries = [];

    // Find target (Sidebar) position
    final RenderBox? sidebarBox =
        _sidebarKey.currentContext?.findRenderObject() as RenderBox?;
    if (sidebarBox == null) return;
    final Offset targetOffset =
        sidebarBox.localToGlobal(Offset.zero) + const Offset(150, 40);

    for (final attachment in attachments) {
      final key = _chipKeys[attachment.id];
      if (key == null) continue;

      final RenderBox? chipBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (chipBox == null) continue;

      final Offset startOffset = chipBox.localToGlobal(Offset.zero);
      final Size blockSize = chipBox.size;

      final entry = OverlayEntry(builder: (context) {
        return _FlyingAttachment(
          startOffset: startOffset,
          endOffset: targetOffset,
          size: blockSize,
          attachment: attachment,
        );
      });
      entries.add(entry);
      Overlay.of(context).insert(entry);
    }

    // Wait for the animation to complete
    await Future.delayed(const Duration(milliseconds: 1000));

    for (final entry in entries) {
      entry.remove();
    }
  }

  void _handleSupportSelected(GroundingSupport? support) {
    if (support == null) {
      // Clicked away or closed popup
      setState(() {
        _activeSupport = null;
        _activeCitationIndices = [];
      });
      return;
    }

    // Extract all citation indices from the support
    setState(() {
      _activeSupport = support;
      _activeCitationIndices = support.groundingChunkIndices;
      if (!_isSidebarExpanded) _isSidebarExpanded = true;
    });

    // Scroll sidebar to the FIRST index
    if (_result != null &&
        _activeCitationIndices.isNotEmpty &&
        _sidebarScrollController.hasClients) {
      final firstIndex = _activeCitationIndices.first;
      // Approximate height or use Scrollable.ensureVisible if we had keys
      _sidebarScrollController.animateTo(
        firstIndex * 110.0, // Approximation
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleCitationSelected(int index) {
    setState(() {
      // If clicking sidebar, highlight that card
      // But what about text? User says "Idle segments must return to having only the Gold Diamond..."
      // implying text should NOT be highlighted if it doesn't match activeSupport?
      // Or maybe we find the support that uses this index? There could be multiple.
      // Let's stick to: Click Sidebar -> Highlight Card. Text clean.
      _activeCitationIndices = [index];
      _activeSupport = null; // Clear text highlight
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  // ===========================================================================
  //  UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: GestureDetector(
        onTap: () {
          // Global Reset on tap "blank space"
          if (_activeCitationIndices.isNotEmpty || _activeSupport != null) {
            setState(() {
              _activeCitationIndices = [];
              _activeSupport = null;
            });
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure full height
          children: [
            // 0. SHELL (Existing Slim Nav Rail - Preserved)
            Container(
              width: 80,
              color: Colors.black,
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  const Icon(Icons.shield_outlined,
                      color: Color(0xFFD4AF37), size: 40),
                  const SizedBox(height: 40),
                  const _SidebarIcons(icon: Icons.dashboard, isActive: true),
                  const _SidebarIcons(icon: Icons.history, isActive: false),
                  const _SidebarIcons(icon: Icons.settings, isActive: false),
                ],
              ),
            ),

            // THE WORKSPACE (3 Columns)
            Expanded(
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // Ensure full height
                children: [
                  // COLUMN 1: Source Material Sidebar (Fixed Width, Animated)
                  Flexible(
                    flex: 0,
                    child: SourceSidebarContainer(
                      key: _sidebarKey,
                      isExpanded: _isSidebarExpanded,
                      onToggle: _toggleSidebar,
                      citations: _result?.groundingCitations ?? [],
                      uploadedAttachments: _migratedAttachments,
                      activeIndices: _activeCitationIndices,
                      onCitationSelected: _handleCitationSelected,
                      scrollController: _sidebarScrollController,
                    ),
                  ),

                  // COLUMN 2: Forensic Analysis Hero (Flex 5)
                  Expanded(
                    flex: 5,
                    child: Stack(
                      fit: StackFit.expand, // Ensure Container fills the space
                      children: [
                        Container(
                          color: const Color(0xFF121212),
                          padding: const EdgeInsets.fromLTRB(
                              32, 32, 32, 120), // Bottom padding for Action Bar
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "FORENSIC ANALYSIS",
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                child: _result == null
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.analytics_outlined,
                                                size: 64,
                                                color: Colors.white
                                                    .withValues(alpha: 0.1)),
                                            const SizedBox(height: 16),
                                            Text(
                                              "Enter text to analyze",
                                              style: GoogleFonts.outfit(
                                                  color: Colors.white24,
                                                  fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: VeriscanInteractiveText(
                                          analysisText: _result!.analysis,
                                          groundingSupports:
                                              _result!.groundingSupports,
                                          groundingCitations:
                                              _result!.groundingCitations,
                                          activeSupport: _activeSupport,
                                          onSupportSelected:
                                              _handleSupportSelected,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        // Floating Action Bar (Pinned to bottom of Column 2)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: GlassActionBar(
                            controller: _inputController,
                            onAnalyze: _handleAnalysis,
                            attachments: _pendingAttachments,
                            chipKeys: _chipKeys,
                            onAddAttachment: _handleAddAttachment,
                            onRemoveAttachment: _handleRemoveAttachment,
                            isLoading: _isLoading,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // COLUMN 3: Verdict & Metrics (Flex 3)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        border: Border(
                          left: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                      ),
                      child: VerdictPane(result: _result),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarIcons extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  const _SidebarIcons({required this.icon, required this.isActive});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Icon(
        icon,
        color: isActive ? const Color(0xFFD4AF37) : Colors.white24,
        size: 24,
      ),
    );
  }
}

class _FlyingAttachment extends StatelessWidget {
  final Offset startOffset;
  final Offset endOffset;
  final Size size;
  final SourceAttachment attachment;

  const _FlyingAttachment({
    required this.startOffset,
    required this.endOffset,
    required this.size,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: startOffset, end: endOffset),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutCubic, // User requested Curves.easeInOutCubic
      builder: (context, offset, child) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 1.0 -
                  (offset.dx - startOffset.dx).abs() /
                      (endOffset.dx - startOffset.dx)
                          .abs()
                          .clamp(1.0, 99999.0)
                          .toDouble() *
                      0.5,
              child: Container(
                width: size.width,
                height: size.height,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.black, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        attachment.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
