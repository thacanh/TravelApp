import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/locations/location_list_screen.dart';
import '../screens/locations/location_detail_screen.dart';
import '../screens/checkin/checkin_screen.dart';
import '../screens/itinerary/itinerary_list_screen.dart';
import '../screens/itinerary/itinerary_detail_screen.dart';
import '../screens/itinerary/itinerary_route_map_screen.dart';
import '../screens/ai/ai_recommend_screen.dart';
import '../screens/ai/chatbot_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/admin/admin_reviews_screen.dart';
import '../screens/admin/admin_locations_screen.dart';
import '../screens/admin/admin_location_form_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String locationList = '/locations';
  static const String locationDetail = '/location-detail';
  static const String checkin = '/checkin';
  static const String itineraryList = '/itineraries';
  static const String itineraryDetail = '/itinerary-detail';
  static const String itineraryRouteMap = '/itinerary-route-map';
  static const String aiRecommend = '/ai-recommend';
  static const String chatbot = '/chatbot';
  static const String map = '/map';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  // Admin routes
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminReviews = '/admin/reviews';
  static const String adminLocations = '/admin/locations';
  static const String adminLocationForm = '/admin/location-form';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      home: (context) => const HomeScreen(),
      locationList: (context) => const LocationListScreen(),
      locationDetail: (context) => const LocationDetailScreen(),
      checkin: (context) => const CheckinScreen(),
      itineraryList: (context) => const ItineraryListScreen(),
      itineraryDetail: (context) => const ItineraryDetailScreen(),
      itineraryRouteMap: (context) => const ItineraryRouteMapScreen(),
      aiRecommend: (context) => const AIRecommendScreen(),
      chatbot: (context) => const ChatbotScreen(),
      map: (context) => const MapScreen(),
      profile: (context) => const ProfileScreen(),
      editProfile: (context) => const EditProfileScreen(),
      // Admin routes
      adminDashboard: (context) => const AdminDashboardScreen(),
      adminUsers: (context) => const AdminUsersScreen(),
      adminReviews: (context) => const AdminReviewsScreen(),
      adminLocations: (context) => const AdminLocationsScreen(),
      adminLocationForm: (context) => const AdminLocationFormScreen(),
    };
  }
}
