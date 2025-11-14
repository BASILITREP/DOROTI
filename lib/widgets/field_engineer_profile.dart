// // lib/widgets/field_engineer_profile.dart
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class FieldEngineerProfile extends StatelessWidget {
//   final Map<String, dynamic> fieldEngineer;
//   final Future<String> Function(double, double) getAddress;
//
//   const FieldEngineerProfile({
//     super.key,
//     required this.fieldEngineer,
//     required this.getAddress,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(15.0),
//       child: Row(
//         children: [
//           const CircleAvatar(
//             radius: 40,
//             backgroundImage: AssetImage('assets/profile.jpg'),
//           ),
//           const SizedBox(width: 12),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 fieldEngineer['name'] ?? 'Field Engineer',
//                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
//               ),
//               const SizedBox(height: 4),
//               FutureBuilder<String>(
//                 future: getAddress(
//                   fieldEngineer['currentLatitude']?.toDouble() ?? 0.0,
//                   fieldEngineer['currentLongitude']?.toDouble() ?? 0.0,
//                 ),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Row(
//                       children: [
//                         Icon(Icons.location_on, color: Colors.black, size: 14),
//                         SizedBox(width: 4),
//                         Text(
//                           "Fetching address...",
//                           style: TextStyle(color: Colors.black, fontSize: 12),
//                         ),
//                       ],
//                     );
//                   } else if (snapshot.hasError) {
//                     return const Text(
//                       "Error fetching address",
//                       style: TextStyle(color: Colors.red, fontSize: 12),
//                     );
//                   } else {
//                     return Text(
//                       snapshot.data ?? "Address not found",
//                       style: const TextStyle(color: Colors.black, fontSize: 12),
//                     );
//                   }
//                 },
//               ),
//               Row(
//                 children: [
//                   const Icon(Icons.access_time, color: Colors.black, size: 14),
//                   const SizedBox(width: 4),
//                   Text(
//                     'Since ${DateFormat('hh:mm a').format(DateTime.now())}',
//                     style: const TextStyle(color: Colors.black, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }