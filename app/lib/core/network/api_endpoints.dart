/// Every path the app talks to, kept in one place so the surface stays visible.
///
/// The shapes mirror the Rails-style `.json` routes the Pulse backend exposes.
abstract final class Api {
  // --- Auth ---------------------------------------------------------------
  static const generateOtp = '/get_otps/generate_otp.json';
  static const verifyOtp = '/get_otps/verify_otp.json';
  static const createUser = '/users/create_user.json';
  static const account = '/api/users/account.json';
  static const consentLogs = '/pms/users/create_consent_logs.json';

  // --- Sites --------------------------------------------------------------
  static const publicSites = '/users/sites.json';
  static const allowedSites = '/pms/sites/allowed_sites.json';
  static const changeSite = '/change_site.json';
  static String site(int id) => '/pms/sites/$id.json';
  static const serviceCategories = '/service_categories.json';

  // --- Events -------------------------------------------------------------
  static const events = '/pms/admin/events.json';
  static const eventCategories = '/pms/admin/events/categories.json';
  static const categoryEvents = '/pms/admin/events/category_events.json';
  static const eventCalendar = '/pms/admin/events/calendar_data.json';
  static const myEvents = '/pms/admin/events/my_events.json';
  static const markAttended = '/pms/admin/events/mark_attended';
  static const addToCalendar = '/pms/admin/events/add_to_calendar.json';
  static const userCalendars = '/user_calendars.json';
  static String event(int id) => '/pms/admin/events/$id.json';
  static String eventRegister(int id) => '/pms/admin/events/$id/register.json';

  // --- Notices ------------------------------------------------------------
  static const notices = '/pms/noticeboards.json';
  static String notice(int id) => '/pms/noticeboards/$id.json';

  // --- Community ----------------------------------------------------------
  static const myCommunities = '/communities/my_communities.json';
  static const otherCommunities = '/communities/other_communities.json';
  static const trendingCommunities = '/communities/trending_communities.json';
  static const categoryCommunities = '/communities/category_communities.json';
  static const communityMembers = '/community_members.json';
  static String community(int id) => '/communities/$id.json';

  static const posts = '/posts.json';
  static String post(int id) => '/posts/$id.json';
  static const comments = '/comments.json';
  static const likeThings = '/like_things.json';

  // --- Wallet & payments --------------------------------------------------
  static const walletData = '/get_wallet_data.json';
  static const initiatePayment = '/pms/easebuzz/initiate_payment';
  static const paymentCallback = '/pms/easebuzz/callback';

  // --- Amenities ----------------------------------------------------------
  static const facilityCategories = '/pms/admin/facility_categories.json';
  static const availableFacilities = '/pms/admin/facility_setups/available_facilities.json';
  static String facility(int id) => '/pms/admin/facility_setups/$id.json';
  static const slotsStatus = '/pms/facility_bookings/slots_status.json';
  static const facilityBookings = '/pms/facility_bookings.json';
  static const myBookings = '/pms/admin/facility_bookings.json';
  static String cancelBooking(int id) => '/pms/facility_bookings/$id.json';

  // --- Documents & directory ----------------------------------------------
  static const documentFolders = '/document_folders.json';
  static const documents = '/documents.json';
  static const sosContacts = '/sos_contacts.json';

  // --- Other modules (next phase) -----------------------------------------
  static const curatedCategories =
      '/osr_setups/osr_categories.json?q[service_tag_eq]=curated';
  static const curatedSubCategories =
      '/osr_setups/osr_sub_categories.json?q[service_tag_eq]=curated';
  static const plusServices = '/plus_services.json?q[active_eq]=true';
  static const restaurants = '/pms/admin/restaurants/gokhana_restaurants.json';
  static const restaurantJwt = '/pms/admin/restaurants/build_gokhana_jwt.json';
  static const entities = '/users/entities.json';
}
