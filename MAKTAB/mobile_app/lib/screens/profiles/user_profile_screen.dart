import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:maktab_app/l10n/app_localizations.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final loc = AppLocalizations.of(context);

    if (user == null) return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('profiles') ?? 'Profile'),
        elevation: 0,
        backgroundColor: Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(bottom: 30, top: 20),
              decoration: BoxDecoration(
                color: Color(0xFF004D40),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(
                      user.role == 'admin' ? CupertinoIcons.person_3_fill : CupertinoIcons.person_solid,
                      size: 60,
                      color: Color(0xFF004D40),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    user.name,
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user.role.toUpperCase(),
                    style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildProfileItem(CupertinoIcons.phone_fill, 'Phone Number', 'N/A'),
                  SizedBox(height: 15),
                  _buildProfileItem(CupertinoIcons.building_2_fill, 'Assigned Role', user.role == 'admin' ? 'Administrator' : 'Ustad / Teacher'),
                  SizedBox(height: 15),
                  _buildProfileItem(CupertinoIcons.calendar, 'Joined At', user.createdAt.split('T')[0]),
                  
                  SizedBox(height: 30),
                  if (user.role == 'teacher') ...[
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(CupertinoIcons.chart_pie_fill, color: Color(0xFF004D40)),
                                SizedBox(width: 10),
                                Text('Performance Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Teacher performance analysis requires multi-month data. Currently tracking daily routines and batch completion rates.',
                              style: TextStyle(color: Colors.grey[700]),
                            )
                          ],
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFF9FBE7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Color(0xFF004D40)),
            ),
            title: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey)),
            subtitle: Text(value, style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
