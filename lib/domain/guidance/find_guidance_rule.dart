import '../../data/guidance_catalog.dart';
import '../storage_guidance.dart';

/// Looks up a [StorageGuidance] rule by [id], or returns null if absent.
StorageGuidance? findGuidanceRule(String id) {
  for (final rule in guidanceCatalog) {
    if (rule.id == id) return rule;
  }
  return null;
}
