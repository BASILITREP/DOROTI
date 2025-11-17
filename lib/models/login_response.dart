class LoginResponse{
  final int userId;
  final String firstName;
  final String lastName;
  final int phoneNumber;
  final String? jwtToken;

  LoginResponse({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required  this.phoneNumber,
    this.jwtToken,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['userId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      phoneNumber: json['phoneNumber'],
      jwtToken: json['jwtToken'],
    );
  }
}