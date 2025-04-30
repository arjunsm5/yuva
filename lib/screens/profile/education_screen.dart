import 'package:flutter/material.dart';

class EducationScreen extends StatefulWidget {
  @override
  _EducationScreenState createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _degreeController = TextEditingController();
  final _institutionController = TextEditingController();
  final _yearController = TextEditingController();
  List<Map<String, String>> educations = [];

  void _addEducation() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        educations.add({
          'degree': _degreeController.text,
          'institution': _institutionController.text,
          'year': _yearController.text,
        });
        _degreeController.clear();
        _institutionController.clear();
        _yearController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Add Education', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _degreeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Degree',
                      labelStyle: const TextStyle(color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter degree' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _institutionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Institution',
                      labelStyle: const TextStyle(color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter institution' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _yearController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Year (e.g., 2023)',
                      labelStyle: const TextStyle(color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter year' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _addEducation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add Education', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: educations.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.grey[850],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(educations[index]['degree']!, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${educations[index]['institution']} | ${educations[index]['year']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            educations.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}