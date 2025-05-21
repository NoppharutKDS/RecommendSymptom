import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  runApp(const SymptomRecommenderApp());
}

class SymptomRecommenderApp extends StatelessWidget {
  const SymptomRecommenderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Symptom Recommender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF2196F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
          secondary: Colors.teal, // Secondary color for recommendations
        ),
        fontFamily: 'Kanit', // Thai-friendly font
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF2196F3),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const SymptomRecommenderScreen(),
    );
  }
}

class Symptom {
  final String id;
  final String name;
  final String nameEn;
  final String category;
  bool isSelected;

  Symptom({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.category,
    this.isSelected = false,
  });

  factory Symptom.fromJson(Map<String, dynamic> json) {
    return Symptom(
      id: json['id'].toString(),
      name: json['name'],
      nameEn: json['name_en'] ?? '',
      category: json['category'] ?? 'ทั่วไป',
    );
  }
}

class SymptomRecommenderScreen extends StatefulWidget {
  const SymptomRecommenderScreen({Key? key}) : super(key: key);

  @override
  State<SymptomRecommenderScreen> createState() => _SymptomRecommenderScreenState();
}

class _SymptomRecommenderScreenState extends State<SymptomRecommenderScreen> with SingleTickerProviderStateMixin {
  List<Symptom> allSymptoms = [];
  List<String> selectedSymptoms = [];
  List<String> recommendedSymptoms = [];
  String searchQuery = '';
  late TabController _tabController;
  bool isLoading = true;
  List<Map<String, dynamic>> symptomDataset = [];

  final List<String> symptomCategories = [
    'ทั้งหมด',
    'ศีรษะ',
    'ตา',
    'หู',
    'คอ',
    'จมูก',
    'ร่างกาย',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: symptomCategories.length, vsync: this);
    _loadSymptoms();
    _loadSymptomDataset();
  }

  Future<void> _loadSymptoms() async {
    try {
      final String data = await rootBundle.loadString('assets/data/symptoms.json');
      final List<dynamic> jsonResult = jsonDecode(data);
      setState(() {
        allSymptoms = jsonResult.map((e) => Symptom.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading symptoms: $e');
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadSymptomDataset() async {
    try {
      final String data = await rootBundle.loadString('assets/data/symptom_dataset.json');
      final List<dynamic> jsonResult = jsonDecode(data);
      setState(() {
        symptomDataset = List<Map<String, dynamic>>.from(jsonResult);
      });
    } catch (e) {
      print('Error loading symptom dataset: $e');
      // If loading fails, provide a fallback dataset
      setState(() {
        symptomDataset = [
          {"search_term": "มีเสมหะ, ไอ"},
          {"search_term": "ไอ, น้ำมูกไหล"},
          {"search_term": "ปวดท้อง"},
          {"search_term": "น้ำมูกไหล"},
          {"search_term": "ตาแห้ง"},
          {"search_term": "ปวดกระดูก"},
        ];
      });
    }
  }

  void _toggleSymptom(String symptomName) {
    setState(() {
      if (selectedSymptoms.contains(symptomName)) {
        selectedSymptoms.remove(symptomName);
      } else {
        selectedSymptoms.add(symptomName);
      }
      // Update recommendations after each selection/deselection
      _updateRecommendations();
    });
  }
  
  void _updateRecommendations() {
    if (selectedSymptoms.isEmpty) {
      setState(() {
        recommendedSymptoms = [];
      });
      return;
    }
    
    // Create a map to count co-occurrence of symptoms
    Map<String, int> recommendationScores = {};
    
    for (var entry in symptomDataset) {
      String searchTerms = entry['search_term'];
      List<String> symptoms = searchTerms.split(',').map((s) => s.trim()).toList();
      
      // Check if any of our selected symptoms appear in this entry
      bool hasSelectedSymptom = false;
      for (String selected in selectedSymptoms) {
        if (symptoms.contains(selected)) {
          hasSelectedSymptom = true;
          break;
        }
      }
      
      // If this entry contains one of our selected symptoms
      if (hasSelectedSymptom) {
        // Add all other symptoms in this entry to our recommendation map
        for (String symptom in symptoms) {
          // Skip if it's already selected or empty
          if (selectedSymptoms.contains(symptom) || symptom.isEmpty) {
            continue;
          }
          
          // Only recommend symptoms that actually exist in our symptoms list
          bool symptomExists = allSymptoms.any((s) => s.name == symptom);
          if (!symptomExists) {
            continue;
          }
          
          // Increment the score for this symptom
          recommendationScores[symptom] = (recommendationScores[symptom] ?? 0) + 1;
        }
      }
    }
    
    // Sort recommendations by score
    var sortedRecommendations = recommendationScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 3 recommendations
    List<String> topRecommendations = sortedRecommendations
        .take(3)
        .map((e) => e.key)
        .toList();
    
    setState(() {
      recommendedSymptoms = topRecommendations;
    });
  }

  List<Symptom> _filterSymptoms(List<Symptom> symptoms) {
    if (searchQuery.isEmpty) return symptoms;
    return symptoms.where((symptom) {
      return symptom.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
             symptom.nameEn.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'ท่านต้องการให้เราช่วยเหลืออะไรวันนี้?',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text('กำลังโหลดข้อมูล...'),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'พิมพ์อาการป่วย หรือ บริการที่ต้องการรับ',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        // Add shadow
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                    ),
                  ),
                  if (selectedSymptoms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'อาการที่เลือก:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: selectedSymptoms.map((symptom) {
                                return FilterChip(
                                  label: Text(
                                    symptom,
                                    style: const TextStyle(
                                      fontSize: 13,
                                    ),
                                  ),
                                  selected: true,
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  checkmarkColor: Theme.of(context).colorScheme.primary,
                                  onSelected: (_) => _toggleSymptom(symptom),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _toggleSymptom(symptom),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Display recommended symptoms if available
                  if (recommendedSymptoms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'แนะนำอาการอื่นที่เกี่ยวข้อง:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: recommendedSymptoms.map((symptom) {
                                return ActionChip(
                                  avatar: Icon(
                                    Icons.add_circle_outline,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  label: Text(
                                    symptom,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  onPressed: () => _toggleSymptom(symptom),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    tabs: symptomCategories.map((cat) => Tab(text: cat)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: symptomCategories.map((category) {
                        List<Symptom> categorySymptoms = category == 'ทั้งหมด'
                            ? allSymptoms
                            : allSymptoms.where((s) => s.category == category).toList();

                        List<Symptom> filtered = _filterSymptoms(categorySymptoms);

                        return filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'ไม่พบอาการที่ตรงกับคำค้นหา',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(16.0),
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: filtered.map((symptom) {
                                            final isSelected = selectedSymptoms.contains(symptom.name);
                                            return ActionChip(
                                              avatar: isSelected
                                                  ? Icon(
                                                      Icons.check_circle,
                                                      size: 16,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    )
                                                  : null,
                                              label: Text(
                                                symptom.name,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Colors.grey.shade800,
                                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                                ),
                                              ),
                                              backgroundColor: isSelected
                                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                                  : Colors.grey.shade100,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                                side: isSelected
                                                    ? BorderSide(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                        width: 1,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              onPressed: () => _toggleSymptom(symptom.name),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                      }).toList(),
                    ),
                  ),
                  // Add a call-to-action button at bottom if symptoms are selected
                  if (selectedSymptoms.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          // Implement next action
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'แนะนำแผนกตรวจ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}