// // lib/widgets/ongoing_routes_panel.dart
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// class OngoingRoutesPanel extends StatelessWidget {
//   final List<Map<String, dynamic>> ongoingRoutes;
//   final Function(Map<String, dynamic>) onStopNavigation;
//
//   const OngoingRoutesPanel({
//     super.key,
//     required this.ongoingRoutes,
//     required this.onStopNavigation,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(12.0),
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Colors.white, Colors.white],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Ongoing Routes',
//                 style: TextStyle(
//                   color: Colors.grey,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: Colors.yellow.shade300,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   '${ongoingRoutes.length}',
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           if (ongoingRoutes.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Center(
//                 child: Column(
//                   children: [
//                     Icon(Icons.directions_off, color: Colors.grey, size: 32),
//                     SizedBox(height: 8),
//                     Text(
//                       'No active routes at the moment',
//                       style: TextStyle(
//                           color: Colors.grey,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       'Accept a service request to start navigation',
//                       style: TextStyle(
//                         color: Colors.grey,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           else
//             Column(
//               children: ongoingRoutes.map((route) {
//                 return _OngoingRouteCard(
//                   route: route,
//                   onStopNavigation: onStopNavigation,
//                 );
//               }).toList(),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // Private widget for the individual route card
// class _OngoingRouteCard extends StatelessWidget {
//   final Map<String, dynamic> route;
//   final Function(Map<String, dynamic>) onStopNavigation;
//
//   const _OngoingRouteCard({
//     required this.route,
//     required this.onStopNavigation,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final status = route['status'] as String;
//     Color statusColor;
//     String statusText;
//
//     switch (status) {
//       case 'in-transit':
//         statusColor = Colors.blue;
//         statusText = 'In Progress';
//         break;
//       case 'arrived':
//         statusColor = Colors.green;
//         statusText = 'Arrived';
//         break;
//       case 'finished':
//         statusColor = Colors.purple;
//         statusText = 'Finished';
//         break;
//       default:
//         statusColor = Colors.grey;
//         statusText = status;
//     }
//
//     final events = route['events'] as List;
//     final startTimeEvent = events.isNotEmpty ? events.first['timestamp'] as DateTime? : null;
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.black.withOpacity(0.1)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.person, color: Colors.grey, size: 16),
//                         const SizedBox(width: 4),
//                         Text(
//                           route['feName'],
//                           style: const TextStyle(
//                             color: Colors.grey,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.grey, size: 14),
//                         const SizedBox(width: 4),
//                         Expanded(
//                           child: Text(
//                             'to ${route['branchName']}',
//                             style: const TextStyle(
//                               color: Colors.grey,
//                               fontSize: 12,
//                             ),
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: statusColor.withOpacity(0.8),
//                   border: Border.all(color: Colors.black.withOpacity(0.1)),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   statusText,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _InfoColumn(
//                 icon: Icons.straighten,
//                 label: 'Distance',
//                 value: route['distance'] ?? '...',
//               ),
//               _InfoColumn(
//                 icon: Icons.access_time,
//                 label: 'ETA',
//                 value: route['estimatedArrival'] != null
//                     ? DateFormat('hh:mm a').format(route['estimatedArrival'] as DateTime)
//                     : '...',
//               ),
//               _InfoColumn(
//                 icon: Icons.attach_money,
//                 label: 'Fare',
//                 value: route['price'] ?? '...',
//               ),
//             ],
//           ),
//           const SizedBox(height: 18),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.play_arrow, color: Colors.white70, size: 14),
//                   const SizedBox(width: 4),
//                   Text(
//                     'Started: ${startTimeEvent != null ? DateFormat('hh:mm a').format(startTimeEvent) : '...'}',
//                     style: const TextStyle(color: Colors.grey, fontSize: 10),
//                   ),
//                 ],
//               ),
//               ElevatedButton(
//                 onPressed: () => onStopNavigation(route),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                 ),
//                 child: const Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.stop, size: 12, color: Colors.white),
//                     SizedBox(width: 4),
//                     Text(
//                       'Stop',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Helper widget para sa mga column
// class _InfoColumn extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final String value;
//
//   const _InfoColumn({
//     required this.icon,
//     required this.label,
//     required this.value,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Icon(icon, color: Colors.grey, size: 14),
//         Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
//         Text(
//           value,
//           style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
//         ),
//       ],
//     );
//   }
// }