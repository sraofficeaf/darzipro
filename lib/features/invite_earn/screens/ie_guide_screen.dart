import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';
import '../widgets/ie_earning_card.dart';
import 'ie_settings_screen.dart';

class PlanScenario {
  final String name;
  final List<int> vals; // [L1, L2, L3, L4]
  final int total;

  const PlanScenario({
    required this.name,
    required this.vals,
    required this.total,
  });
}

class IeGuideScreen extends StatefulWidget {
  const IeGuideScreen({super.key});

  @override
  State<IeGuideScreen> createState() => _IeGuideScreenState();
}

class _IeGuideScreenState extends State<IeGuideScreen> {
  String _selectedPkg = 'full'; // 'mobile' | 'full' | 'full3yr'

  // Expandable state for 4 Level cards (Level 1 open by default)
  final Map<int, bool> _expandedLevels = {
    1: true,
    2: false,
    3: false,
    4: false,
  };

  static const Map<String, PlanScenario> _pkgData = {
    'mobile': PlanScenario(
      name: 'Basic Plan',
      vals: [1800, 300, 180, 120],
      total: 2400,
    ),
    'full': PlanScenario(
      name: 'Professional Plan',
      vals: [5250, 875, 525, 350],
      total: 7000,
    ),
    'full3yr': PlanScenario(
      name: 'Enterprise Plan',
      vals: [10500, 1750, 1050, 700],
      total: 14000,
    ),
  };

  String _fmt(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'Rs $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;
    final surface2 = context.surface2;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;
    final text3 = context.text3;

    final currentScenario = _pkgData[_selectedPkg]!;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: text1),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'How Earning Works',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: text1,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HERO ────────────────────────────────────────────────────────
            Column(
              children: [
                const Text('💰', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 8),
                Text(
                  'Invite & Earn Guide',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: text1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Simple steps to understand exactly how much you earn — no confusing math, just real numbers.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: text2,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── STEP 1 CARD ─────────────────────────────────────────────────
            _buildCard(
              context,
              badge: 'STEP 1',
              title: 'Share Your Code',
              description:
                  'Send your invite code or link to another tailor shop owner. When they register on Darzi Pro using your code, you start earning.',
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFlowItem(context, icon: '🧵', label: 'You'),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('→', style: TextStyle(color: ieAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildFlowItem(context, icon: '💬', label: 'Share Code'),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('→', style: TextStyle(color: ieAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildFlowItem(context, icon: '✅', label: 'They Join'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── STEP 2 CARD (Interactive Tree) ─────────────────────────────
            _buildCard(
              context,
              badge: 'STEP 2',
              title: 'Your Plan = How Deep You Earn',
              description:
                  'Not just direct invites! If the person you invited ALSO invites someone, you can earn from that too — up to 4 people deep. Your own plan decides how far it goes.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),

                  // Sub-section A: Chain Diagram
                  _buildChainDiagram(context),
                  const SizedBox(height: 14),

                  // Sub-section B: 3 Plan Info Cards
                  _buildPlanExampleRow('📱 Basic Plan', 'You only earn from direct invites (Level 1)'),
                  const SizedBox(height: 6),
                  _buildPlanExampleRow('⭐ Professional Plan', 'You earn 2 levels deep (Level 1-2)'),
                  const SizedBox(height: 6),
                  _buildPlanExampleRow('💎 Enterprise Plan', 'You earn all 4 levels deep — maximum earning!'),

                  const SizedBox(height: 18),
                  Text(
                    '👀 See it with real names:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: text1,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sub-section C: Package Filter Buttons
                  Row(
                    children: [
                      Expanded(child: _buildFilterBtn('mobile', '📱', 'Basic Plan')),
                      const SizedBox(width: 6),
                      Expanded(child: _buildFilterBtn('full', '⭐', 'Professional Plan')),
                      const SizedBox(width: 6),
                      Expanded(child: _buildFilterBtn('full3yr', '💎', 'Enterprise Plan')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Showing: if everyone below joins with the SAME package',
                      style: GoogleFonts.inter(fontSize: 10, fontStyle: FontStyle.italic, color: text3),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Named Family Tree Diagram
                  _buildNamedTree(context, currentScenario),
                  const SizedBox(height: 14),

                  // Highlighted Total Notice Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ieAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ieAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💰 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(fontSize: 11.5, color: text1, height: 1.4),
                              children: [
                                const TextSpan(text: 'Total from this whole chain: '),
                                TextSpan(
                                  text: _fmt(currentScenario.total),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: ieAccent,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' — and it keeps growing every time someone new joins anywhere in this line!',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── STEP 3 INTRO CARD ───────────────────────────────────────────
            _buildCard(
              context,
              badge: 'STEP 3',
              title: 'Exact Amounts You Earn',
              description:
                  'Tap each level below to see exactly how much you get, based on which plan the person joins with.',
            ),
            const SizedBox(height: 12),

            // ── 4 EXPANDABLE LEVEL CARDS ────────────────────────────────────
            _buildLevelCard(
              context,
              levelNum: 1,
              badgeText: 'L1',
              title: 'Direct Invite',
              subtitle: 'Someone joins using YOUR code',
              rows: const [
                ('📱', 'Basic Plan', 1800),
                ('⭐', 'Professional Plan', 5250),
                ('💎', 'Enterprise Plan', 10500),
              ],
            ),
            const SizedBox(height: 8),

            _buildLevelCard(
              context,
              levelNum: 2,
              badgeText: 'L2',
              title: 'Their Invite',
              subtitle: 'Needs: Professional Plan or higher',
              rows: const [
                ('📱', 'Basic Plan', 300),
                ('⭐', 'Professional Plan', 875),
                ('💎', 'Enterprise Plan', 1750),
              ],
              lockedNotice: '🔒 Only earned if YOU are Professional Plan or higher',
            ),
            const SizedBox(height: 8),

            _buildLevelCard(
              context,
              levelNum: 3,
              badgeText: 'L3',
              title: '3 Levels Deep',
              subtitle: 'Needs: Enterprise Plan',
              rows: const [
                ('📱', 'Basic Plan', 180),
                ('⭐', 'Professional Plan', 525),
                ('💎', 'Enterprise Plan', 1050),
              ],
              lockedNotice: '🔒 Only earned if YOU are Enterprise Plan',
            ),
            const SizedBox(height: 8),

            _buildLevelCard(
              context,
              levelNum: 4,
              badgeText: 'L4',
              title: '4 Levels Deep',
              subtitle: 'Needs: Enterprise Plan',
              rows: const [
                ('📱', 'Basic Plan', 120),
                ('⭐', 'Professional Plan', 350),
                ('💎', 'Enterprise Plan', 700),
              ],
              lockedNotice: '🔒 Only earned if YOU are Enterprise Plan',
            ),
            const SizedBox(height: 16),

            // ── REAL EXAMPLE CARD ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ieAccent.withValues(alpha: 0.12),
                    surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ieAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Real Example',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ieAccent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 12, color: text1, height: 1.6),
                      children: [
                        const TextSpan(text: "You're on the "),
                        TextSpan(text: "Enterprise Plan", style: TextStyle(fontWeight: FontWeight.bold, color: ieAccent)),
                        const TextSpan(text: ". You invite "),
                        TextSpan(text: "Ahmad", style: TextStyle(fontWeight: FontWeight.bold, color: text1)),
                        const TextSpan(text: ", who joins as "),
                        TextSpan(text: "Professional Plan", style: TextStyle(fontWeight: FontWeight.bold, color: ieAccent)),
                        const TextSpan(text: " — you instantly earn "),
                        TextSpan(text: "Rs 5,250", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: ieAccent)),
                        const TextSpan(text: ".\n\nLater, Ahmad invites "),
                        TextSpan(text: "Bilal", style: TextStyle(fontWeight: FontWeight.bold, color: text1)),
                        const TextSpan(text: ", who joins as "),
                        TextSpan(text: "Basic Plan", style: TextStyle(fontWeight: FontWeight.bold, color: ieAccent)),
                        const TextSpan(text: ". Since you're on Enterprise Plan, you also earn from this — "),
                        TextSpan(text: "Rs 300", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: ieAccent)),
                        const TextSpan(text: " more, automatically!"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── STORAGE ADD-ON EARNINGS SECTION ─────────────────────────────
            _buildCard(
              context,
              title: '📦 Storage Add-on Earnings',
              description:
                  'If someone you invited buys extra storage, you earn from that too (Level 1 shown below — same level rules apply for deeper levels).',
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('STORAGE TYPE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: text3)),
                            Text('YOU EARN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: text3)),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: border),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Monthly (Rs 1,200)', style: GoogleFonts.inter(fontSize: 12, color: text1)),
                            Text('Rs 180', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: ieAccent)),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: border),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Annual (Rs 10,000)', style: GoogleFonts.inter(fontSize: 12, color: text1)),
                            Text('Rs 1,500', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: ieAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── BOTTOM TIP & NAVIGATION ─────────────────────────────────────
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IeSettingsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Text(
                  '💡 Tip: Upgrade your own plan anytime to unlock deeper earning levels — visit Settings → Plan & Storage',
                  style: GoogleFonts.inter(fontSize: 11.5, color: text2, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Helper Card Container Widget ──────────────────────────────────────────
  Widget _buildCard(
    BuildContext context, {
    String? badge,
    required String title,
    required String description,
    Widget? child,
  }) {
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: ieAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: ieAccent),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: text1),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 12, color: text2, height: 1.5),
          ),
          ?child,

        ],
      ),
    );
  }

  Widget _buildFlowItem(BuildContext context, {required String icon, required String label}) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ieAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ieAccent.withValues(alpha: 0.3)),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: context.text2)),
      ],
    );
  }

  Widget _buildChainDiagram(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildChainNode(context, label: 'YOU', text: 'You', isYou: true, isActive: true),
        Expanded(child: Container(height: 2, color: ieAccent)),
        _buildChainNode(context, label: 'L1', text: 'B', isYou: false, isActive: true),
        Expanded(child: Container(height: 2, color: ieAccent)),
        _buildChainNode(context, label: 'L2', text: 'C', isYou: false, isActive: true),
        Expanded(child: Container(height: 2, color: context.border)),
        _buildChainNode(context, label: 'L3', text: 'D', isYou: false, isActive: false),
        Expanded(child: Container(height: 2, color: context.border)),
        _buildChainNode(context, label: 'L4', text: 'E', isYou: false, isActive: false),
      ],
    );
  }

  Widget _buildChainNode(
    BuildContext context, {
    required String label,
    required String text,
    required bool isYou,
    required bool isActive,
  }) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isYou
                ? ieAccent
                : (isActive ? const Color(0xFFF5A623) : context.surface2),
            border: isActive
                ? null
                : Border.all(color: context.border, style: BorderStyle.solid),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: (isYou || isActive) ? Colors.white : context.text3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: context.text3)),
      ],
    );
  }

  Widget _buildPlanExampleRow(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: context.text1)),
          const SizedBox(height: 1),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: context.text2)),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String key, String icon, String label) {
    final isSelected = _selectedPkg == key;
    return InkWell(
      onTap: () => setState(() => _selectedPkg = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? ieAccent.withValues(alpha: 0.12) : context.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? ieAccent : context.border, width: 1.5),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? ieAccent : context.text2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamedTree(BuildContext context, PlanScenario scenario) {
    return Column(
      children: [
        // Node 0: You
        _buildTreeNode(
          context,
          avatarText: 'You',
          avatarGradient: const [Color(0xFF10CBA0), Color(0xFF059669)],
          name: 'You',
          subtitle: 'Enterprise Plan',
          showLine: false,
        ),

        // Node 1: Ahmad (Level 1)
        _buildTreeNode(
          context,
          avatarText: 'A',
          avatarGradient: const [Color(0xFFF5A623), Color(0xFFB45309)],
          name: 'Ahmad',
          levelTag: 'Level 1',
          subtitle: 'You invited Ahmad · ${scenario.name}',
          earnAmount: _fmt(scenario.vals[0]),
          showLine: true,
          lineActive: true,
        ),

        // Node 2: Najeeb (Level 2)
        _buildTreeNode(
          context,
          avatarText: 'N',
          avatarGradient: const [Color(0xFFF5A623), Color(0xFFB45309)],
          name: 'Najeeb',
          levelTag: 'Level 2',
          subtitle: 'Ahmad invited Najeeb · ${scenario.name}',
          earnAmount: _fmt(scenario.vals[1]),
          showLine: true,
          lineActive: true,
        ),

        // Node 3: Bilal (Level 3)
        _buildTreeNode(
          context,
          avatarText: 'B',
          avatarGradient: const [Color(0xFFF5A623), Color(0xFFB45309)],
          name: 'Bilal',
          levelTag: 'Level 3',
          subtitle: 'Najeeb invited Bilal · ${scenario.name}',
          earnAmount: _fmt(scenario.vals[2]),
          showLine: true,
          lineActive: true,
        ),

        // Node 4: Sara (Level 4)
        _buildTreeNode(
          context,
          avatarText: 'S',
          avatarGradient: const [Color(0xFFF5A623), Color(0xFFB45309)],
          name: 'Sara',
          levelTag: 'Level 4',
          subtitle: 'Bilal invited Sara · ${scenario.name}',
          earnAmount: _fmt(scenario.vals[3]),
          showLine: true,
          lineActive: true,
        ),

        // Node 5: Level 5 Locked
        _buildTreeNode(
          context,
          avatarText: '?',
          isLocked: true,
          name: 'Anyone Sara invites',
          levelTag: 'Level 5',
          subtitle: 'Too far — chain stops at Level 4',
          earnAmount: '—',
          showLine: true,
          lineActive: false,
        ),
      ],
    );
  }

  Widget _buildTreeNode(
    BuildContext context, {
    required String avatarText,
    List<Color>? avatarGradient,
    bool isLocked = false,
    required String name,
    String? levelTag,
    required String subtitle,
    String? earnAmount,
    required bool showLine,
    bool lineActive = false,
  }) {
    final border = context.border;
    final text1 = context.text1;
    final text3 = context.text3;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Vertical Connecting Line & Avatar
          SizedBox(
            width: 42,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (showLine)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: Container(color: lineActive ? ieAccent : border),
                  ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: avatarGradient != null ? LinearGradient(colors: avatarGradient) : null,
                    color: isLocked ? context.surface2 : null,
                    border: isLocked ? Border.all(color: border, style: BorderStyle.solid) : null,
                  ),
                  child: Center(
                    child: Text(
                      avatarText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? text3 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isLocked ? text3 : text1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (levelTag != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isLocked ? context.surface2 : ieAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  levelTag,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isLocked ? text3 : ieAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(fontSize: 10, color: text3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (earnAmount != null)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          earnAmount == '—' ? '—' : '+$earnAmount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? text3 : ieAccent,
                          ),
                        ),
                        Text(
                          isLocked ? 'not earned' : 'you earn',
                          style: GoogleFonts.inter(fontSize: 8.5, color: text3),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context, {
    required int levelNum,
    required String badgeText,
    required String title,
    required String subtitle,
    required List<(String, String, int)> rows,
    String? lockedNotice,
  }) {
    final isOpen = _expandedLevels[levelNum] ?? false;
    final surface = context.surface;
    final surface2 = context.surface2;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedLevels[levelNum] = !isOpen;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ieAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: ieAccent.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        badgeText,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: ieAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: text1),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(fontSize: 10.5, color: text2),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: text2,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(
                children: [
                  ...rows.map(
                    (r) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(r.$1, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(r.$2, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: text1)),
                            ],
                          ),
                          Text(
                            _fmt(r.$3),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: ieAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (lockedNotice != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        lockedNotice,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
