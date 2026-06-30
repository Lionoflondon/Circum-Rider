part of 'verification_bloc.dart';

enum IdType {
  driversLicense,
  internationalPassport,
  workPermit,
  vehicleRegistration,
}

abstract class VerificationState extends Equatable {
  const VerificationState();

  @override
  List<Object> get props => [];
}

class VerificationInitial extends VerificationState {}
