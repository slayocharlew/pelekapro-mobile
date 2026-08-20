class DeliveryRequirements {
  const DeliveryRequirements({
    required this.proofSupported,
    required this.availableProofTypes,
  });

  final bool proofSupported;
  final List<String> availableProofTypes;
}
