import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fact_check_service.dart';
import '../models/grounding_models.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/result_card.dart';
import '../widgets/veriscan_interactive_text.dart';

import '../widgets/evidence_card.dart';
import '../widgets/input_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FactCheckService _service = FactCheckService();
  AnalysisResponse? _result;
  bool _isLoading = false;

  Future<void> _handleAnalysis(
      String? text, String? url, PlatformFile? image) async {
    debugPrint(
        'DASHBOARD DEBUG: Analyzing - Text: $text, URL: $url, Image: ${image?.name}');

    if (text == null && url == null && image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide input (Text, URL, or Image)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final result = await _service.analyzeNews(
        text: text,
        url: url,
        imageBytes: image?.bytes,
        imageFilename: image?.name,
      );

      setState(() {
        _result = result;
      });
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: ResponsiveLayout(
        mobileBody: _buildMobileLayout(),
        desktopBody: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMobileHeader(),
            const SizedBox(height: 24),
            _BentoCard(
              title: "INPUT DATA",
              child: InputSection(
                onAnalyze: _handleAnalysis,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 16),
            if (_result != null || _isLoading) ...[
              _BentoCard(
                title: "ANALYSIS RESULT",
                child: ResultCard(result: _result),
              ),
              const SizedBox(height: 16),
              _BentoCard(
                title: "FORENSIC ANALYSIS",
                child: _result == null
                    ? const Center(
                        child: Icon(Icons.analytics_outlined,
                            color: Colors.white12, size: 40))
                    : VeriscanInteractiveText(
                        analysisText: _result!.analysis,
                        groundingSupports: _result!.groundingSupports,
                        groundingCitations: _result!.groundingCitations,
                      ),
              ),
              const SizedBox(height: 16),
              _BentoCard(
                title: "GROUNDING EVIDENCE",
                child: _buildEvidenceList(),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 80,
          color: Colors.black,
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.shield_outlined,
                  color: Color(0xFFD4AF37), size: 40),
              const SizedBox(height: 40),
              const _SidebarItem(icon: Icons.dashboard, isActive: true),
              const _SidebarItem(icon: Icons.history, isActive: false),
              const _SidebarItem(icon: Icons.settings, isActive: false),
            ],
          ),
        ),

        // Main Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopHeader(),
                const SizedBox(height: 30),
                Expanded(
                  child: SingleChildScrollView(
                    child: StaggeredGrid.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        // 1. Input Zone (Takes 2 Columns)
                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 2,
                          child: _BentoCard(
                            title: "INPUT DATA",
                            child: InputSection(
                              onAnalyze: _handleAnalysis,
                              isLoading: _isLoading,
                            ),
                          ),
                        ),

                        // 2. Result Card (Merged Verdict + Score) (Takes 2 Columns)
                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 1,
                          child: _BentoCard(
                            title: "ANALYSIS RESULT",
                            child: ResultCard(result: _result),
                          ),
                        ),

                        // 3. Analysis Text (Takes 2 Columns)
                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 1, // Adjusted height
                          child: _BentoCard(
                            title: "FORENSIC ANALYSIS",
                            child: _result == null
                                ? const Center(
                                    child: Icon(Icons.analytics_outlined,
                                        color: Colors.white12, size: 40))
                                : SingleChildScrollView(
                                    child: VeriscanInteractiveText(
                                      analysisText: _result!.analysis,
                                      groundingSupports:
                                          _result!.groundingSupports,
                                      groundingCitations:
                                          _result!.groundingCitations,
                                    ),
                                  ),
                          ),
                        ),

                        // 4. Evidence (Takes 4 Columns - Full Width)
                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 2,
                          child: _BentoCard(
                            title: "GROUNDING EVIDENCE",
                            child: _buildEvidenceList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VERISCAN DASHBOARD',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Multimodal Forensic Analysis Engine',
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _StatusBadge(),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VERISCAN DASHBOARD',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            Text(
              'Multimodal Forensic Analysis Engine',
              style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
        _StatusBadge(),
      ],
    );
  }

  Widget _buildEvidenceList() {
    if (_result == null) {
      return const Center(
          child: Text("No evidence loaded.",
              style: TextStyle(color: Colors.white24)));
    }
    if (_result!.groundingCitations.isEmpty) {
      return Center(
        child: Text(
          "No specific external citations found.\nAnalysis based on internal knowledge and context.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true, // Needed for mobile column
      physics: const ClampingScrollPhysics(), // Scrollable inside the parent
      itemCount: _result!.groundingCitations.length,
      itemBuilder: (context, index) {
        final citation = _result!.groundingCitations[index];
        return EvidenceCard(
          title: citation.title,
          snippet: citation.snippet,
          url: citation.url,
        );
      },
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _BentoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              if (constraints.maxHeight.isFinite)
                Expanded(child: child)
              else
                child,
            ],
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;

  const _SidebarItem({required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5))
            : null,
      ),
      child: Icon(
        icon,
        color: isActive ? const Color(0xFFD4AF37) : Colors.white24,
        size: 24,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A23),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Text(
            'SYSTEM ONLINE',
            style: GoogleFonts.outfit(
              color: const Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
