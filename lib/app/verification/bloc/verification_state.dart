part of 'verification_bloc.dart';

enum IdType { driversLicense, internationalPassport, workPermit }

abstract class VerificationState extends Equatable {
  const VerificationState();

  @override
  List<Object> get props => [];
}

class VerificationInitial extends VerificationState {}
