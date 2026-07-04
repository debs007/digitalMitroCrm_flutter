class ChannelMember {
  final String id;
  final String name;
  final String email;
  final String avatar;

  ChannelMember({required this.id, required this.name, required this.email, required this.avatar});

  factory ChannelMember.fromJson(Map<String, dynamic> json) {
    return ChannelMember(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
    );
  }
}

/// purpose/industry/website/location — the 4 free-text fields the backend
/// groups under channelDetails, separate from the top-level description.
class ChannelExtraDetails {
  final String purpose;
  final String industry;
  final String website;
  final String location;

  ChannelExtraDetails({
    this.purpose = '',
    this.industry = '',
    this.website = '',
    this.location = '',
  });

  factory ChannelExtraDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ChannelExtraDetails();
    return ChannelExtraDetails(
      purpose: json['purpose']?.toString() ?? '',
      industry: json['industry']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'industry': industry,
        'website': website,
        'location': location,
      };
}

/// Full channel detail — GET /api/:id returns the channel with `members`
/// resolved to {_id, name, email, avatar} instead of raw ObjectIds.
class ChannelDetail {
  final String id;
  final String name;
  final String description;
  final String image;
  final String statusTag;
  final List<String> tags;
  final List<ChannelMember> members;
  final String? ownerId;
  final ChannelExtraDetails extraDetails;

  ChannelDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.statusTag,
    required this.tags,
    required this.members,
    this.ownerId,
    ChannelExtraDetails? extraDetails,
  }) : extraDetails = extraDetails ?? ChannelExtraDetails();

  factory ChannelDetail.fromJson(Map<String, dynamic> json) {
    return ChannelDetail(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      statusTag: json['statusTag']?.toString() ?? 'Active',
      tags: (json['tags'] is List) ? List<String>.from(json['tags']) : [],
      members: (json['members'] is List)
          ? (json['members'] as List)
              .where((m) => m is Map)
              .map((m) => ChannelMember.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : [],
      ownerId: json['owner']?.toString(),
      extraDetails: ChannelExtraDetails.fromJson(
        json['channelDetails'] is Map ? Map<String, dynamic>.from(json['channelDetails']) : null,
      ),
    );
  }
}
