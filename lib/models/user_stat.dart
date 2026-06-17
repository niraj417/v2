class UserStat {
  final String email;
  final int leadsClaimed;
  final int leadsContacted;
  final int leadsInterested;
  final int leadsClosed;
  final int leadsNotInterested;
  final int leadsGenerated;

  UserStat({
    required this.email,
    required this.leadsClaimed,
    required this.leadsContacted,
    required this.leadsInterested,
    required this.leadsClosed,
    required this.leadsNotInterested,
    required this.leadsGenerated,
  });
}
