import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> fieldEngineer;

  const ProfileScreen({super.key, required this.fieldEngineer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DOROTI',
              style: GoogleFonts.libreBaskerville(
                fontSize: 25,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                color: const Color.fromARGB(255, 246, 255, 168),
              ),
              textAlign: TextAlign.center,
            ),
            Image(
              image: const AssetImage('assets/equicomLogo.png'),
              height: 40,
              width: 40,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Hero(
                tag: 'profile_avatar',
                child: CircleAvatar(
                    backgroundColor: Color.fromARGB(
                      255,
                      245,
                      255,
                      140,
                    ),
                    radius: 50,
                    child: Text(
                      fieldEngineer['firstName'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 50,
                      ),
                    )
                ),
              ),
              const SizedBox(height: 24),
              Text(
                fieldEngineer['firstName'] ?? 'N/A',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fieldEngineer['email'] ?? 'N/A',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              _buildInfoCard(
                context,
                'Employee ID',
                fieldEngineer['id']?.toString() ?? 'N/A',
                Icons.badge,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                'Phone Number',
                fieldEngineer['phoneNumber'] ?? 'Field Engineering',
                Icons.phone,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                context,
                'Last Name',
                fieldEngineer['lastName'] ?? 'Field Engineer',
                Icons.work,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String label, String value, IconData icon) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6760F6)),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
