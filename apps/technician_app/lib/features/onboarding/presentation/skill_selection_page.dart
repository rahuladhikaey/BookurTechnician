import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../dashboard/presentation/main_shell_page.dart';
import '../data/skill_service.dart';
import '../domain/skill_models.dart';

class SkillSelectionPage extends ConsumerStatefulWidget {
  final bool isOnboarding;

  const SkillSelectionPage({super.key, this.isOnboarding = false});

  @override
  ConsumerState<SkillSelectionPage> createState() => _SkillSelectionPageState();
}

class _SkillSelectionPageState extends ConsumerState<SkillSelectionPage> {
  final SkillService _skillService = SkillService();
  final TextEditingController _searchController = TextEditingController();

  List<SkillCategoryModel> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  // Selected skill IDs and experience map: skillId -> experienceYears
  final Map<String, int> _selectedSkills = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    final categories = await _skillService.fetchCatalogHierarchy();
    final profile = await _skillService.fetchMySkillProfile();

    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;

        // Prepopulate existing skills if editing
        if (profile != null && profile.skills.isNotEmpty) {
          for (var item in profile.skills) {
            _selectedSkills[item.skillId] = item.experienceYears;
          }
        }
      });
    }
  }

  void _toggleSkill(SkillItemModel skill) {
    setState(() {
      if (_selectedSkills.containsKey(skill.id)) {
        _selectedSkills.remove(skill.id);
      } else {
        _selectedSkills[skill.id] = 2; // Default 2 years experience
      }
    });
  }

  void _setExperience(String skillId, int years) {
    setState(() {
      _selectedSkills[skillId] = years;
    });
  }

  Future<void> _saveSkills() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one skill to receive customer job requests.'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving skills to server...'),
        duration: Duration(seconds: 1),
      ),
    );

    List<Map<String, dynamic>> payload = _selectedSkills.entries.map((entry) {
      final sId = entry.key;
      final exp = entry.value;
      String sName = '';
      String cId = '';
      String cName = '';
      String canonicalId = sId;

      for (final cat in _categories) {
        for (final s in cat.skills) {
          if (s.id == sId || s.canonicalServiceId == sId) {
            sName = s.name;
            cId = cat.id;
            cName = cat.name;
            canonicalId = s.canonicalServiceId;
            break;
          }
        }
        if (sName.isNotEmpty) break;
      }

      if (sName.isEmpty) {
        sName = sId
            .replaceAll('sk_', '')
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
            .join(' ');
      }

      return {
        'id': canonicalId,
        'skillId': canonicalId,
        'canonicalServiceId': canonicalId,
        'name': sName,
        'skillName': sName,
        'categoryId': cId,
        'categoryName': cName,
        'experienceYears': exp,
        'verificationStatus': 'VERIFIED',
        'enabled': true,
      };
    }).toList();

    final savedProfile = await _skillService.saveSelectedSkills(payload);

    if (mounted) {
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedProfile != null
                ? 'Saved to server! ${_selectedSkills.length} skills active for live matching.'
                : 'Saved locally, waiting to sync (${_selectedSkills.length} skills).',
          ),
          backgroundColor: const Color(0xFF198754),
        ),
      );

      if (widget.isOnboarding) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShellPage()),
          (route) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter categories and skills based on search query
    final filteredCategories = _categories.map((cat) {
      if (_searchQuery.isEmpty) return cat;

      final filteredSkills = cat.skills.where((s) {
        return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      return SkillCategoryModel(
        id: cat.id,
        name: cat.name,
        slug: cat.slug,
        iconUrl: cat.iconUrl,
        displayOrder: cat.displayOrder,
        skills: filteredSkills,
      );
    }).where((cat) => cat.skills.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F6),
      appBar: AppBar(
        title: const Text(
          'Select Your Skills',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF222222),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: widget.isOnboarding
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF222222)),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF46B12)))
          : Column(
              children: [
                // Top Instructions & Search Container
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFEEE8E2))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Choose your service expertise',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF77716C),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBE4D5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFBE4D5)),
                            ),
                            child: Text(
                              '${_selectedSkills.length} Selected',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF46B12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Search bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search skills (e.g. Ceiling Fan, AC Deep Cleaning...)',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF77716C)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFF46B12), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFFCF9F6),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFEEE8E2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFEEE8E2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFF46B12), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category list with chips
                Expanded(
                  child: filteredCategories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 48, color: Color(0xFF77716C)),
                              const SizedBox(height: 8),
                              Text(
                                'No matching skills found for "$_searchQuery"',
                                style: const TextStyle(color: Color(0xFF77716C), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, catIndex) {
                            final category = filteredCategories[catIndex];
                            return _buildCategorySection(category);
                          },
                        ),
                ),

                // Bottom CTA Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(top: BorderSide(color: Color(0xFFEEE8E2))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: PrimaryButton(
                      text: widget.isOnboarding
                          ? 'Confirm Skills & Enter Console'
                          : 'Save Selected Skills (${_selectedSkills.length})',
                      onPressed: _saveSkills,
                      isLoading: _isSaving,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategorySection(SkillCategoryModel category) {
    int selectedCountInCat = category.skills.where((s) => _selectedSkills.containsKey(s.id)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedCountInCat > 0 ? const Color(0xFFF46B12).withValues(alpha: 0.3) : const Color(0xFFEEE8E2),
          width: selectedCountInCat > 0 ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFBE4D5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Color(0xFFF46B12),
              size: 20,
            ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          subtitle: Text(
            '${category.skills.length} available skills${selectedCountInCat > 0 ? ' • $selectedCountInCat selected' : ''}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selectedCountInCat > 0 ? FontWeight.w700 : FontWeight.w500,
              color: selectedCountInCat > 0 ? const Color(0xFFF46B12) : const Color(0xFF77716C),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: category.skills.map((skill) {
                  final isSelected = _selectedSkills.containsKey(skill.id);
                  final expYears = _selectedSkills[skill.id] ?? 2;

                  return _buildSkillChip(skill, isSelected, expYears);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChip(SkillItemModel skill, bool isSelected, int expYears) {
    return GestureDetector(
      onTap: () => _toggleSkill(skill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBE4D5) : const Color(0xFFFCF9F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFF46B12) : const Color(0xFFEEE8E2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              size: 16,
              color: isSelected ? const Color(0xFFF46B12) : const Color(0xFF77716C),
            ),
            const SizedBox(width: 6),
            Text(
              skill.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFFF46B12) : const Color(0xFF222222),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                padding: EdgeInsets.zero,
                iconSize: 14,
                tooltip: 'Experience Years',
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF46B12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${expYears}y',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                onSelected: (years) => _setExperience(skill.id, years),
                itemBuilder: (context) => [1, 2, 3, 5, 8, 10].map((y) {
                  return PopupMenuItem<int>(
                    value: y,
                    child: Text('$y ${y == 1 ? 'year' : 'years'} experience'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
