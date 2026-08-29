import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/aeternum_certificate.dart';
import '../models/work.dart';

class CertificateService {
  static const _certificateSelect =
      '*, work:works(title, cover_url), issuer:profiles!aeternum_certificates_issuer_profile_id_fkey(username, display_name), owner:profiles!aeternum_certificates_owner_profile_id_fkey(username, display_name), events:certificate_events(event_type, note, created_at)';

  Future<List<Work>> getEligibleWorks(String profileId) async {
    final data = await supabase
        .from('works')
        .select(
          '*, profiles!works_profile_id_fkey(username, display_name, avatar_url)',
        )
        .eq('profile_id', profileId)
        .eq('status', 'published')
        .eq('is_public', true)
        .order('created_at', ascending: false);
    return (data as List)
        .map((item) => Work.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<AeternumCertificate>> getMyCertificates(
    String profileId,
  ) async {
    final data = await supabase
        .from('aeternum_certificates')
        .select(_certificateSelect)
        .or('issuer_profile_id.eq.$profileId,owner_profile_id.eq.$profileId')
        .order('issued_at', ascending: false);
    return (data as List)
        .map(
          (item) => AeternumCertificate.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<AeternumCertificate?> getForWork(String workId) async {
    if (supabase.auth.currentUser != null) {
      final privateData = await supabase
          .from('aeternum_certificates')
          .select(_certificateSelect)
          .eq('work_id', workId)
          .neq('status', 'revoked')
          .order('issued_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (privateData != null) {
        return AeternumCertificate.fromMap(privateData);
      }
    }
    final data = await supabase.rpc(
      'get_work_aeternum_certificate',
      params: {'p_work_id': workId},
    );
    return _fromRpc(data);
  }

  Future<AeternumCertificate?> verifyCertificate(String number) async {
    final normalized = number.trim().toUpperCase();
    if (supabase.auth.currentUser != null) {
      final privateData = await supabase
          .from('aeternum_certificates')
          .select(_certificateSelect)
          .eq('certificate_number', normalized)
          .maybeSingle();
      if (privateData != null) {
        return AeternumCertificate.fromMap(privateData);
      }
    }
    final data = await supabase.rpc(
      'verify_aeternum_certificate',
      params: {'p_certificate_number': normalized},
    );
    return _fromRpc(data);
  }

  Future<String> issueCertificate({
    required String workId,
    required String editionLabel,
    required bool ownerPublic,
  }) async {
    try {
      final data = await supabase.rpc(
        'issue_aeternum_certificate',
        params: {
          'p_work_id': workId,
          'p_edition_label': editionLabel.trim(),
          'p_owner_public': ownerPublic,
        },
      );
      return data as String;
    } on PostgrestException catch (error) {
      throw CertificateFailure(error.message);
    }
  }

  Future<void> setOwnerPublic(String certificateId, bool isPublic) async {
    try {
      await supabase.rpc(
        'set_certificate_owner_public',
        params: {
          'p_certificate_id': certificateId,
          'p_owner_public': isPublic,
        },
      );
    } on PostgrestException catch (error) {
      throw CertificateFailure(error.message);
    }
  }

  Future<void> revokeCertificate(String certificateId, String reason) async {
    try {
      await supabase.rpc(
        'revoke_aeternum_certificate',
        params: {
          'p_certificate_id': certificateId,
          'p_reason': reason.trim(),
        },
      );
    } on PostgrestException catch (error) {
      throw CertificateFailure(error.message);
    }
  }

  AeternumCertificate? _fromRpc(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return AeternumCertificate.fromMap(value);
    }
    if (value is Map) {
      return AeternumCertificate.fromMap(Map<String, dynamic>.from(value));
    }
    return null;
  }
}

class CertificateFailure implements Exception {
  final String message;

  const CertificateFailure(this.message);

  @override
  String toString() => message;
}
