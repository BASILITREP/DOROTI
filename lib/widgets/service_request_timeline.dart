// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:timelines_plus/timelines_plus.dart';
//
// class ServiceRequestTimeline extends StatelessWidget {
//   final Map<String, dynamic> route;
//   final Function(Map<String, dynamic>) onFinishService;
//   final Function(Map<String, dynamic>) onLeaveBranch;
//
//   const ServiceRequestTimeline({
//     super.key,
//     required this.route,
//     required this.onFinishService,
//     required this.onLeaveBranch,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final events = route['events'] as List<Map<String, dynamic>>;
//     final status = route['status'];
//
//     final allSteps = ['Accepted', 'In Transit', 'Arrived', 'Finished Service', 'Left Branch'];
//
//     Map<String, dynamic>? findEvent(String status) {
//       try {
//         return events.firstWhere((e) => e['status'] == status);
//       } catch (e) {
//         return null;
//       }
//     }
//
//     return Container(
//       margin: EdgeInsets.all(12.0),
//       padding: EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Activity for ${route['branchName']}',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
//           ),
//           SizedBox(height: 20),
//           Timeline.tileBuilder(
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             theme: TimelineThemeData(
//               nodePosition: 0,
//               connectorTheme: ConnectorThemeData(thickness: 2.0),
//               indicatorTheme: IndicatorThemeData(size: 20.0),
//             ),
//             builder: TimelineTileBuilder.connected(
//               itemCount: allSteps.length,
//               connectionDirection: ConnectionDirection.before,
//               contentsBuilder: (context, index) {
//                 final stepStatus = allSteps[index];
//                 final event = findEvent(stepStatus);
//
//                 return Padding(
//                   padding: const EdgeInsets.only(left: 12.0, bottom: 20.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         stepStatus,
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: event != null ? Colors.black : Colors.grey,
//                         ),
//                       ),
//                       if (event != null)
//                         Text(
//                           DateFormat('hh:mm a').format(event['timestamp']),
//                           style: TextStyle(color: Colors.grey, fontSize: 12),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//               indicatorBuilder: (context, index) {
//                 final event = findEvent(allSteps[index]);
//                 final isCurrent = (allSteps[index] == 'In Transit' && status == 'in-transit') ||
//                                   (allSteps[index] == 'Arrived' && status == 'arrived');
//
//                 if (event != null) {
//                   if(isCurrent){
//                      return DotIndicator(color: Colors.blue);
//                   }
//                   return DotIndicator(color: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 12));
//                 } else {
//                   return OutlinedDotIndicator(color: Colors.grey.shade300, borderWidth: 2);
//                 }
//               },
//               connectorBuilder: (context, index, type) {
//                 if (index > 0) {
//                   final prevEvent = findEvent(allSteps[index - 1]);
//                   if (prevEvent != null) {
//                     return SolidLineConnector(color: Colors.green);
//                   }
//                 }
//                 return SolidLineConnector(color: Colors.grey.shade300);
//               },
//             ),
//           ),
//           if (status == 'arrived')
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () => onFinishService(route),
//                 icon: Icon(Icons.check_circle_outline),
//                 label: Text('Mark as Finished'),
//                 style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green, foregroundColor: Colors.white),
//               ),
//             ),
//           if (status == 'finished')
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () => onLeaveBranch(route),
//                 icon: Icon(Icons.directions_walk),
//                 label: Text('Leave Branch'),
//                 style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.orange, foregroundColor: Colors.white),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }