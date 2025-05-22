import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() => runApp(SymptomRecommenderApp());

class SymptomRecommenderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Symptom Recommender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF2196F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF2196F3),
          brightness: Brightness.light,
          secondary: Colors.teal,
        ),
        fontFamily: 'Kanit',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Color(0xFF2196F3),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: SymptomRecommenderScreen(),
    );
  }
}

class Symptom {
  String id;
  String name;
  String category;
  bool isSelected;

  Symptom({
    required this.id,
    required this.name,
    required this.category,
    this.isSelected = false,
  });

  factory Symptom.fromJson(Map<String, dynamic> json) {
    return Symptom(
      id: json['id'].toString(),
      name: json['name'],
      category: json['category'] ?? 'ทั้งหมด',
    );
  }
}

class PatientData {
  String gender;
  int age;
  String searchTerm;
  List<String> yesSymptoms;
  List<String> diseases;
  List<String> procedures;

  PatientData({
    required this.gender,
    required this.age,
    required this.searchTerm,
    required this.yesSymptoms,
    required this.diseases,
    required this.procedures,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    List<String> symptoms = [];
    
    if (json['summary'] != null && json['summary']['yes_symptoms'] != null) {
      var yesSymptoms = json['summary']['yes_symptoms'];
      for (var symptom in yesSymptoms) {
        if (symptom['text'] != null) {
          symptoms.add(symptom['text'].toString());
        }
      }
    }

    return PatientData(
      gender: json['gender'] ?? '',
      age: json['age'] ?? 0,
      searchTerm: json['search_term'] ?? '',
      yesSymptoms: symptoms,
      diseases: List<String>.from(json['summary']?['diseases'] ?? []),
      procedures: List<String>.from(json['summary']?['procedures'] ?? []),
    );
  }
}

class SymptomRecommenderScreen extends StatefulWidget {
  @override
  _SymptomRecommenderScreenState createState() => _SymptomRecommenderScreenState();
}

class _SymptomRecommenderScreenState extends State<SymptomRecommenderScreen> 
    with SingleTickerProviderStateMixin {
  
  List<Symptom> allSymptoms = [];
  List<String> selectedSymptoms = [];
  List<String> recommendedSymptoms = [];
  String searchQuery = '';
  TabController? _tabController;
  bool isLoading = true;
  List<PatientData> patientDataset = [];

  List<String> symptomCategories = [
    'ทั้งหมด', 'ศีรษะ', 'ตา', 'หู', 'คอ', 'จมูก', 
    'ผิวหนัง', 'กล้ามเนื้อ', 'ภายใน', 'จิตใจ'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: symptomCategories.length, vsync: this);
    loadSymptoms();
    loadPatientData();
  }

  loadSymptoms() async {
    try {
      String data = await rootBundle.loadString('assets/data/symptoms.json');
      List<dynamic> jsonResult = jsonDecode(data);
      setState(() {
        allSymptoms = jsonResult.map((e) => Symptom.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading symptoms: $e');
      setState(() => isLoading = false);
    }
  }
  
  loadPatientData() async {
    try {
      String data = await rootBundle.loadString('assets/data/patient_data.json');
      List<dynamic> jsonResult = jsonDecode(data);
      setState(() {
        patientDataset = jsonResult.map((e) => PatientData.fromJson(e)).toList();
      });
    } catch (e) {
      print('Error loading patient data: $e');
      // Fallback data
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

  toggleSymptom(String symptomName) {
    setState(() {
      if (selectedSymptoms.contains(symptomName)) {
        selectedSymptoms.remove(symptomName);
      } else {
        selectedSymptoms.add(symptomName);
      }
      updateRecommendations();
    });
  }
  
  updateRecommendations() {
    if (selectedSymptoms.isEmpty) {
      setState(() => recommendedSymptoms = []);
      return;
    }
    
    Map<String, int> scores = {};
    
    for (var patient in patientDataset) {
      List<String> searchSymptoms = patient.searchTerm
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      
      List<String> allPatientSymptoms = [
        ...searchSymptoms,
        ...patient.yesSymptoms,
      ].toSet().toList();
      
      bool hasMatch = false;
      for (String selected in selectedSymptoms) {
        if (allPatientSymptoms.contains(selected)) {
          hasMatch = true;
          break;
        }
      }
      
      if (hasMatch) {
        for (String symptom in allPatientSymptoms) {
          if (selectedSymptoms.contains(symptom) || symptom.isEmpty) continue;
          
          bool exists = allSymptoms.any((s) => s.name == symptom);
          if (!exists) continue;
          
          scores[symptom] = (scores[symptom] ?? 0) + 1;
        }
      }
    }
    
    var sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    setState(() {
      recommendedSymptoms = sorted.take(3).map((e) => e.key).toList();
    });
  }

  List<Symptom> filterSymptoms(List<Symptom> symptoms) {
    if (searchQuery.isEmpty) return symptoms;
    return symptoms.where((symptom) {
      return symptom.name.toLowerCase().contains(searchQuery.toLowerCase()) ;
    }).toList();
  }

  Widget buildSelectedSymptomsSection() {
    if (selectedSymptoms.isEmpty) return SizedBox.shrink();
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
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
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: true,
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                  onSelected: (_) => toggleSymptom(symptom),
                  deleteIcon: Icon(Icons.close, size: 14),
                  onDeleted: () => toggleSymptom(symptom),
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRecommendationsSection() {
    if (recommendedSymptoms.isEmpty) return SizedBox.shrink();
    
    return Padding(
      padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                SizedBox(width: 4),
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
            SizedBox(height: 6),
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
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => toggleSymptom(symptom),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSymptomGrid(List<Symptom> symptoms) {
    if (symptoms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 14),
            Text(
              'ไม่พบอาการที่ตรงกับคำค้นหา',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, selectedSymptoms.isNotEmpty ? 80.0 : 16.0),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: symptoms.map((symptom) {
            bool isSelected = selectedSymptoms.contains(symptom.name);
            return ActionChip(
              avatar: isSelected
                  ? Icon(Icons.check_circle, size: 14, color: Theme.of(context).colorScheme.primary)
                  : null,
              label: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 120),
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
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () => toggleSymptom(symptom.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'ท่านต้องการให้เราช่วยเหลืออะไรวันนี้?',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูล...'),
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
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'พิมพ์อาการป่วย หรือ บริการที่ต้องการรับ',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => searchQuery = value),
                    ),
                  ),
                  buildSelectedSymptomsSection(),
                  buildRecommendationsSection(),
                  SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 3,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                    tabs: symptomCategories.map((cat) => Tab(text: cat)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: symptomCategories.map((category) {
                        List<Symptom> categorySymptoms = category == 'ทั้งหมด'
                            ? allSymptoms
                            : allSymptoms.where((s) => s.category == category).toList();

                        List<Symptom> filtered = filterSymptoms(categorySymptoms);
                        return buildSymptomGrid(filtered);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: selectedSymptoms.isNotEmpty
          ? Container(
              width: MediaQuery.of(context).size.width - 32,
              height: 44,
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  // Not need
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: Text(
                  'แนะนำแผนกตรวจ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}