// // lib/widgets/service_request_list.dart
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// class ServiceRequestList extends StatelessWidget {
//   final bool isLoading;
//   final List<dynamic> serviceRequests;
//   final List<Map<String, dynamic>> ongoingRoutes;
//   final int fieldEngineerId;
//   final Function(int) onAcceptRequest;
//
//   const ServiceRequestList({
//     super.key,
//     required this.isLoading,
//     required this.serviceRequests,
//     required this.ongoingRoutes,
//     required this.fieldEngineerId,
//     required this.onAcceptRequest,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 2),
//           if (isLoading)
//             const Center(
//               child: Padding(
//                 padding: EdgeInsets.all(32.0),
//                 child: CircularProgressIndicator(),
//               ),
//             )
//           else if (serviceRequests.isEmpty)
//             const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
//                   SizedBox(height: 16),
//                   Text('No service requests found', style: TextStyle(color: Colors.grey, fontSize: 16)),
//                 ],
//               ),
//             )
//           else
//             ListView(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               padding: EdgeInsets.zero,
//               children: serviceRequests
//                   .map((request) => _ServiceRequestCard(
//                         request: request,
//                         fieldEngineerId: fieldEngineerId,
//                         ongoingRoutes: ongoingRoutes,
//                         onAcceptRequest: onAcceptRequest,
//                       ))
//                   .toList(),
//             ),
//         ],
//       ),
//     );
//   }
// }
//
// // Private widget para sa card, dito na rin nakatira
// class _ServiceRequestCard extends StatelessWidget {
//   final Map<String, dynamic> request;
//   final int fieldEngineerId;
//   final List<Map<String, dynamic>> ongoingRoutes;
//   final Function(int) onAcceptRequest;
//
//   const _ServiceRequestCard({
//     required this.request,
//     required this.fieldEngineerId,
//     required this.ongoingRoutes,
//     required this.onAcceptRequest,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     bool isUnassigned = request['fieldEngineerId'] == null;
//     bool hasOngoingRoute = ongoingRoutes.any((route) => route['serviceRequestId'] == request['id']);
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12.0),
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
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
//                     const Text(
//                       'Available Service Requests',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
//                     ),
//                     const SizedBox(height: 7),
//                     Text(
//                       request['branch']?['name'] ?? 'Unknown Branch',
//                       style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 4),
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.grey, size: 14),
//                         const SizedBox(width: 4),
//                         Expanded(
//                           child: Text(
//                             request['branch']?['address'] ?? 'No address',
//                             style: const TextStyle(color: Colors.grey, fontSize: 12),
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                 decoration: BoxDecoration(
//                   color: isUnassigned ? Colors.orange.withOpacity(0.8) : Colors.green.withOpacity(0.8),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   isUnassigned ? 'Pending' : (hasOngoingRoute ? 'Active' : 'Accepted'),
//                   style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ],
//           ),
//           const Divider(color: Colors.white24, height: 24),
//           if (isUnassigned)
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () {
//                   HapticFeedback.lightImpact();
//                   onAcceptRequest(request['id']);
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//                 icon: const Icon(Icons.check_circle_outline, size: 18),
//                 label: const Text('Accept Request'),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }