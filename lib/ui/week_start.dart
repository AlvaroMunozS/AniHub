/// Regions whose week starts on Sunday, from the Unicode CLDR week data.
///
/// CLDR also has regions that start on Saturday or Friday; the app only
/// offers Monday and Sunday, so they get Monday like everywhere else.
const Set<String> _sundayRegions = <String>{
  'AG', 'AS', 'BD', 'BR', 'BS', 'BT', 'BW', 'BZ', 'CA', 'CN', 'CO', 'DM', //
  'DO', 'ET', 'GT', 'GU', 'HK', 'HN', 'ID', 'IL', 'IN', 'JM', 'JP', 'KE', //
  'KH', 'KR', 'LA', 'MH', 'MM', 'MO', 'MT', 'MX', 'MZ', 'NI', 'NP', 'PA', //
  'PE', 'PH', 'PK', 'PR', 'PT', 'PY', 'SA', 'SG', 'SV', 'TH', 'TT', 'TW', //
  'UM', 'US', 'VE', 'VI', 'WS', 'YE', 'ZA', 'ZW', //
};

/// Returns the first day of the week in the region [countryCode], as
/// [DateTime.monday] or [DateTime.sunday]; Monday when the region is unknown.
int firstWeekdayOfRegion(String? countryCode) =>
    _sundayRegions.contains(countryCode?.toUpperCase())
    ? DateTime.sunday
    : DateTime.monday;
