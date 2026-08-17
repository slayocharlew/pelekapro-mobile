class DeliveryRequirements {
  const DeliveryRequirements({
    required this.pinRequired,
    required this.proofSupported,
    required this.availableProofTypes,
  });

  final bool pinRequired;
  final bool proofSupported;
  final List<String> availableProofTypes;
}
