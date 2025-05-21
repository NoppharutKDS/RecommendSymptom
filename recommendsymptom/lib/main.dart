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
      category: json['category'] ?? 'ทั้งหมด',
    );
  }
}

class PatientData {
  final String gender;
  final int age;
  final String searchTerm;
  final List<String> yesSymptoms;
  final List<String> diseases;
  final List<String> procedures;

  PatientData({
    required this.gender,
    required this.age,
    required this.searchTerm,
    required this.yesSymptoms,
    required this.diseases,
    required this.procedures,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    List<String> extractYesSymptoms = [];
    
    // Extract symptoms from summary.yes_symptoms
    if (json['summary'] != null && json['summary']['yes_symptoms'] != null) {
      for (var symptom in json['summary']['yes_symptoms']) {
        if (symptom['text'] != null) {
          extractYesSymptoms.add(symptom['text'].toString());
        }
      }
    }

    return PatientData(
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      searchTerm: json['search_term'] ?? '',
      yesSymptoms: extractYesSymptoms,
      diseases: List<String>.from(json['summary']?['diseases'] ?? []),
      procedures: List<String>.from(json['summary']?['procedures'] ?? []),
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
  List<PatientData> patientDataset = [];

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
    _loadPatientDataset();
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
  
  Future<void> _loadPatientDataset() async {
    try {
      final String data = await rootBundle.loadString('assets/data/patient_data.json');
      final List<dynamic> jsonResult = jsonDecode(data);
      setState(() {
        patientDataset = jsonResult.map((e) => PatientData.fromJson(e)).toList();
      });
    } catch (e) {
      print('Error loading patient dataset: $e');
      // If loading fails, provide a fallback dataset
      setState(() {
        patientDataset = [
          PatientData(
            gender: 'male',
            age: 28,
            searchTerm: 'มีเสมหะ, ไอ',
            yesSymptoms: ['เสมหะ', 'ไอ'],
            diseases: [],
            procedures: [],
          ),
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
    
    for (var patientData in patientDataset) {
      // Get symptoms from search_term
      List<String> searchTermSymptoms = patientData.searchTerm
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      
      // Also include symptoms from yes_symptoms for better matching
      List<String> allPatientSymptoms = [
        ...searchTermSymptoms,
        ...patientData.yesSymptoms,
      ].toSet().toList(); // Remove duplicates
      
      // Check if any of our selected symptoms appear in this patient's data
      bool hasSelectedSymptom = false;
      for (String selected in selectedSymptoms) {
        if (allPatientSymptoms.contains(selected)) {
          hasSelectedSymptom = true;
          break;
        }
      }
      
      // If this patient data contains one of our selected symptoms
      if (hasSelectedSymptom) {
        // Add all other symptoms in this patient's data to our recommendation map
        for (String symptom in allPatientSymptoms) {
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
            fontSize: 16,
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
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'อาการที่เลือก:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selectedSymptoms.map((symptom) {
                                return FilterChip(
                                  label: Text(
                                    symptom,
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  selected: true,
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  checkmarkColor: Theme.of(context).colorScheme.primary,
                                  onSelected: (_) => _toggleSymptom(symptom),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => _toggleSymptom(symptom),
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        width: double.infinity,
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'แนะนำอาการอื่นที่เกี่ยวข้อง:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: recommendedSymptoms.map((symptom) {
                                return ActionChip(
                                  avatar: Icon(
                                    Icons.add_circle_outline,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  label: Text(
                                    symptom,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                    const SizedBox(height: 14),
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
                                padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, selectedSymptoms.isNotEmpty ? 80.0 : 16.0),
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: filtered.map((symptom) {
                                            final isSelected = selectedSymptoms.contains(symptom.name);
                                            return ActionChip(
                                              avatar: isSelected
                                                  ? Icon(
                                                      Icons.check_circle,
                                                      size: 14,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    )
                                                  : null,
                                              label: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 120),
                                                child: Text(
                                                  symptom.name,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Theme.of(context).colorScheme.primary
                                                        : Colors.grey.shade800,
                                                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              backgroundColor: isSelected
                                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                                  : Colors.grey.shade100,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                side: isSelected
                                                    ? BorderSide(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                        width: 1,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                ],
              ),
            ),
      // Move button to floating position to fix overflow
      floatingActionButton: selectedSymptoms.isNotEmpty
          ? Container(
              width: MediaQuery.of(context).size.width - 32,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  // Implement next action
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'แนะนำแผนกตรวจ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}