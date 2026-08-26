import 'package:flutter/material.dart'; // Add this import at the top
import 'package:latlong2/latlong.dart';

class ShopData {
  // 🟢 NEW: ValueNotifier broadcasts changes instantly to any listening screen!
  static ValueNotifier<Set<String>> savedShopNames = ValueNotifier<Set<String>>({});

  static final List<Map<String, dynamic>> shops =
/*  [

    // --- RELIGION & COMMUNITY ---
    {
      "name": "Masjid Jamek Changkat Jering",
      "location": const LatLng(4.7942, 100.7208),
      "category": "religion",
      "rating": 5.0,
      "reviews": 400,
      "openHour": 5, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['Solat Jumaat', 'Religious Classes', 'Community Hall'],
      "recentReviews": [{'userName': 'Haji Din', 'rating': 5, 'comment': 'Beautiful masjid and very clean.'}]
    },
    // Example of a mobile business in your data:
    {
      'name': 'Pijoy Mobile Barber',
      'category': 'barber',
      'location': LatLng(3.1400, 101.6900), // Center of their coverage area
      'rating': 4.9,
      'reviews': 12,
      'services': ['House Call Haircut', 'Beard Trim'],
      'isMobileService': true, // <--- ADD THIS FLAG
      'openHour': 10,
      'closeHour': 20,
    },
    {
      "name": "Pejabat Penghulu Mukim Bukit Gantang",
      "location": const LatLng(4.7925, 100.7185),
      "category": "service",
      "rating": 4.4,
      "reviews": 15,
      "openHour": 8, "openMinute": 0, "closeHour": 17, "closeMinute": 00, // Closes at 5:30 PM
      "services": ['Community Support', 'Local Documentation'],
      "recentReviews": [{'userName': 'Zali', 'rating': 4, 'comment': 'Helpful staff.'}]
    },

    // --- EDUCATION ---
    {
      "name": "SK Changkat Jering",
      "location": const LatLng(4.7965, 100.7165),
      "category": "school",
      "rating": 4.6,
      "reviews": 85,
      "openHour": 7, "openMinute": 30, "closeHour": 14, "closeMinute": 15, // 7:30 AM - 2:15 PM
      "services": ['Primary Education', 'Extra-curricular Activities'],
      "recentReviews": [{'userName': 'Cikgu Sarah', 'rating': 5, 'comment': 'Great school environment.'}]
    },

    // --- ESSENTIAL SERVICES ---
    {
      "name": "Pasar Awam Changkat Jering",
      "location": const LatLng(4.7932, 100.7215),
      "category": "market",
      "rating": 4.5,
      "reviews": 530,
      "openHour": 6, "openMinute": 0, "closeHour": 12, "closeMinute": 0,
      "services": ['Fresh Produce', 'Breakfast Stalls'],
      "recentReviews": [{'userName': 'Mak Cik Kiah', 'rating': 5, 'comment': 'Best place for fresh fish.'}]
    },
    {
      "name": "Petronas Changkat Jering",
      "location": const LatLng(4.7915, 100.7195),
      "category": "gas",
      "rating": 4.3,
      "reviews": 1100,
      "openHour": 6, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['Fuel', 'ATM', 'Kedai Mesra'],
      "recentReviews": [{'userName': 'Ravi', 'rating': 4, 'comment': 'Convenient stop.'}]
    },
    {
      "name": "Klinik Kesihatan CJ",
      "location": const LatLng(4.7955, 100.7170),
      "category": "health",
      "rating": 4.2,
      "reviews": 150,
      "openHour": 8, "openMinute": 0, "closeHour": 17, "closeMinute": 0, // Closes at 5:30 PM
      "services": ['Outpatient Treatment', 'Pharmacy', 'Maternal Health'],
      "recentReviews": [{'userName': 'Liana', 'rating': 4, 'comment': 'Staff are professional.'}]
    },

    // --- FOOD & DINING ---
    {
      "name": "Nasi Lemak Beratur CJ",
      "location": const LatLng(4.7938, 100.7222),
      "category": "food",
      "rating": 4.9,
      "reviews": 88,
      "openHour": 18, "openMinute": 0, "closeHour": 2, "closeMinute": 30, // 6:00 PM to 2:30 AM
      "services": ['Nasi Lemak', 'Teh Tarik'],
      "recentReviews": [{'userName': 'Daus', 'rating': 5, 'comment': 'Sambal is legendary.'}]
    },
    {
      "name": "Mee Udang Nur Ziana",
      "location": const LatLng(4.7850, 100.7120),
      "category": "food",
      "rating": 4.6,
      "reviews": 1200,
      "openHour": 11, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Mee Udang', 'Seafood'],
      "recentReviews": [{'userName': 'Farhan', 'rating': 5, 'comment': 'Huge prawns!'}]
    },

    // --- AUTOMOTIVE & WORKSHOPS ---
    {
      "name": "Bengkel Kereta Man",
      "location": const LatLng(4.7900, 100.7235),
      "category": "workshop",
      "rating": 4.7,
      "reviews": 34,
      "openHour": 9, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Car Repair', 'Spare Parts'],
      "recentReviews": [{'userName': 'Zul', 'rating': 5, 'comment': 'Abang Man is very honest.'}]
    },
    {
      'name': 'Changkat Jering Auto Workshop',
      'category': 'workshop',
      'location': const LatLng(4.791, 100.73),
      'rating': 4.8,
      'reviews': 124,
      'openHour': 9, 'openMinute': 0, 'closeHour': 18, 'closeMinute': 0,
      'services': ['Oil Change', 'Tire Alignment', 'Engine Repair', 'Car Wash'],
      'recentReviews': [
        {'userName': 'Ahmad Firdaus', 'rating': 5, 'comment': 'Really fast service!'},
        {'userName': 'Siti Nurhaliza', 'rating': 4, 'comment': 'Good mechanics.'}
      ]
    },

    // --- PERSONAL CARE ---
    {
      "name": "Zul Barber Shop",
      "location": const LatLng(4.7924, 100.7205),
      "category": "barber",
      "rating": 4.6,
      "reviews": 45,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 45, // 10:00 AM to 9:45 PM
      "services": ['Haircut', 'Shaving'],
      "recentReviews": [{'userName': 'Amir', 'rating': 5, 'comment': 'Modern style.'}]
    },
  ];
 */
    [
    // --- KUALA LUMPUR & SELANGOR ---
    {
      "name": "Joe's Barber Shop KL",
      "category": "barber",
      "location": const LatLng(3.1390, 101.6869), // KL City Center
      "rating": 4.8,
      "reviews": 342,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Classic Fade', 'Hot Towel Shave', 'Hair Wash'],
      "recentReviews": [{'userName': 'Ahmad', 'rating': 5, 'comment': 'Best fade in KL.'}]
    },
    {
      'name': 'Pijoy Mobile Stylist',
      'category': 'barber',
      'location': const LatLng(3.1400, 101.6900), // Coverage Center
      'rating': 4.9,
      'reviews': 88,
      'services': ['House Call Haircut', 'Beard Trim', 'Kids Cut'],
      'isMobileService': true,
      'openHour': 9, 'openMinute': 0, 'closeHour': 21, 'closeMinute': 0,
    },
    {
      "name": "Nimroc Barbershop",
      "category": "barber",
      "location": const LatLng(3.0738, 101.5183), // Shah Alam
      "rating": 4.7,
      "reviews": 512,
      "openHour": 10, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['Pompadour', 'Line Up', 'Hair Tattoo'],
    },
    {
      "name": "Glamour Mobile Salon",
      "category": "salon",
      "location": const LatLng(3.1198, 101.6763), // Bangsar coverage
      "rating": 4.9,
      "reviews": 115,
      "openHour": 8, "openMinute": 30, "closeHour": 19, "closeMinute": 0,
      "services": ['Home Hair Color', 'Bridal Styling', 'Keratin Treatment'],
      "isMobileService": true,
    },
    {
      "name": "Lexis Premium Salon",
      "category": "salon",
      "location": const LatLng(3.1575, 101.7116), // KLCC area
      "rating": 4.6,
      "reviews": 230,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Hair Coloring', 'Rebonding', 'Scalp Treatment'],
    },
    {
      "name": "Subang Grooming Co.",
      "category": "barber",
      "location": const LatLng(3.0480, 101.5830), // SS15 Subang Jaya
      "rating": 4.5,
      "reviews": 189,
      "openHour": 11, "openMinute": 0, "closeHour": 22, "closeMinute": 30,
      "services": ['Student Cut', 'Beard Sculpting'],
      "recentReviews": [{'userName': 'Kevin', 'rating': 4, 'comment': 'Great price for students.'}]
    },
    {
      "name": "Cyberjaya Cuts Mobile",
      "category": "barber",
      "location": const LatLng(2.9202, 101.6508), // Cyberjaya
      "rating": 4.8,
      "reviews": 45,
      "openHour": 18, "openMinute": 0, "closeHour": 23, "closeMinute": 59, // Late night mobile
      "services": ['Midnight House Call', 'Executive Trim'],
      "isMobileService": true,
    },

    // --- PERAK (Including Tapah & Ipoh) ---
    {
      "name": "Tapah Campus Barber",
      "category": "barber",
      "location": const LatLng(4.1950, 101.2600), // Tapah
      "rating": 4.9,
      "reviews": 120,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['UiTM Student Cut', 'Basic Fade'],
      "recentReviews": [{'userName': 'Daus', 'rating': 5, 'comment': 'Mantap bro, clean cut.'}]
    },
    {
      "name": "Ipoh Old Town Gentlemen",
      "category": "barber",
      "location": const LatLng(4.5956, 101.0901), // Ipoh
      "rating": 4.7,
      "reviews": 310,
      "openHour": 9, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Classic Scissor Cut', 'Straight Razor Shave'],
    },
    {
      "name": "Daus Mobile Grooming",
      "category": "barber",
      "location": const LatLng(4.2000, 101.2550), // Tapah area mobile
      "rating": 5.0,
      "reviews": 34,
      "openHour": 14, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['Dorm Call Cut', 'Event Styling'],
      "isMobileService": true,
    },
    {
      "name": "Zul Barber Shop",
      "location": const LatLng(4.7924, 100.7205), // Taiping / Perak North
      "category": "barber",
      "rating": 4.6,
      "reviews": 45,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 45,
      "services": ['Haircut', 'Shaving'],
      "recentReviews": [{'userName': 'Amir', 'rating': 5, 'comment': 'Modern style.'}]
    },

    // --- PENANG & NORTHERN REGION ---
    {
      "name": "Georgetown Gentlemen",
      "category": "barber",
      "location": const LatLng(5.4141, 100.3288), // Georgetown, Penang
      "rating": 4.8,
      "reviews": 421,
      "openHour": 11, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Skin Fade', 'Pomade Styling'],
    },
    {
      "name": "Penang Street Salon",
      "category": "salon",
      "location": const LatLng(5.4160, 100.3320), // Penang
      "rating": 4.5,
      "reviews": 150,
      "openHour": 10, "openMinute": 0, "closeHour": 19, "closeMinute": 30,
      "services": ['Balayage', 'Hair Spa', 'Trim'],
    },
    {
      "name": "Alor Setar Pomade & Cut",
      "category": "barber",
      "location": const LatLng(6.1210, 100.3600), // Alor Setar, Kedah
      "rating": 4.6,
      "reviews": 98,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Haircut', 'Hair Wash'],
    },
    {
      "name": "Northern Mobile Curls",
      "category": "salon",
      "location": const LatLng(5.3500, 100.3000), // Penang island coverage
      "rating": 4.9,
      "reviews": 67,
      "openHour": 9, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Mobile Blowout', 'Perming'],
      "isMobileService": true,
    },

    // --- JOHOR & SOUTHERN REGION ---
    {
      "name": "JB Street Barber",
      "category": "barber",
      "location": const LatLng(1.4927, 103.7414), // Johor Bahru
      "rating": 4.7,
      "reviews": 560,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Taper Fade', 'Beard Trim'],
    },
    {
      "name": "Elite Mobile Grooming JB",
      "category": "barber",
      "location": const LatLng(1.5000, 103.7500), // JB Mobile
      "rating": 4.8,
      "reviews": 112,
      "openHour": 8, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Hotel Call Haircut', 'VIP Grooming'],
      "isMobileService": true,
    },
    {
      "name": "The Duchess Salon",
      "category": "salon",
      "location": const LatLng(1.4850, 103.7620), // JB
      "rating": 4.6,
      "reviews": 310,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Digital Perm', 'Coloring'],
    },
    {
      "name": "Melaka Classic Cuts",
      "category": "barber",
      "location": const LatLng(2.1896, 102.2501), // Malacca
      "rating": 4.5,
      "reviews": 145,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Retro Cut', 'Kids Haircut'],
    },
    {
      "name": "Seremban Trims",
      "category": "barber",
      "location": const LatLng(2.7258, 101.9378), // Negeri Sembilan
      "rating": 4.4,
      "reviews": 89,
      "openHour": 9, "openMinute": 30, "closeHour": 19, "closeMinute": 30,
      "services": ['Standard Cut', 'Hair Wash'],
    },

    // --- EAST COAST (Pahang, Terengganu, Kelantan) ---
    {
      "name": "Kuantan Edge Barber",
      "category": "barber",
      "location": const LatLng(3.8126, 103.3256), // Pahang
      "rating": 4.7,
      "reviews": 210,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Burst Fade', 'Shaving'],
    },
    {
      "name": "KT Clipper Mobile",
      "category": "barber",
      "location": const LatLng(5.3302, 103.1408), // Kuala Terengganu
      "rating": 4.8,
      "reviews": 56,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Mobile Haircut', 'Beard Trim'],
      "isMobileService": true,
    },
    {
      "name": "Kota Bharu Cuts",
      "category": "barber",
      "location": const LatLng(6.1254, 102.2381), // Kelantan
      "rating": 4.5,
      "reviews": 130,
      "openHour": 9, "openMinute": 0, "closeHour": 18, "closeMinute": 0, // Closes earlier
      "services": ['Basic Cut', 'Kids Cut'],
    },

    // --- EAST MALAYSIA (Sabah & Sarawak) ---
    {
      "name": "Borneo Fadez",
      "category": "barber",
      "location": const LatLng(5.9804, 116.0735), // Kota Kinabalu, Sabah
      "rating": 4.8,
      "reviews": 405,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Skin Fade', 'Line Up', 'Hair Tattoo'],
    },
    {
      "name": "Kuching Style Studio",
      "category": "salon",
      "location": const LatLng(1.5535, 110.3593), // Kuching, Sarawak
      "rating": 4.7,
      "reviews": 275,
      "openHour": 10, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Hair Treatment', 'Trim', 'Blowdry'],
    },
    {
      "name": "Sabah Mobile Beauty",
      "category": "salon",
      "location": const LatLng(5.9900, 116.0800), // KK Mobile
      "rating": 5.0,
      "reviews": 42,
      "openHour": 9, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['House Call Styling', 'Bridal Makeup'],
      "isMobileService": true,
    },

    // --- EXTRA MIX ---
    {
      "name": "Putrajaya Executive Salon",
      "category": "salon",
      "location": const LatLng(2.9264, 101.6964), // Putrajaya
      "rating": 4.6,
      "reviews": 190,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Executive Wash & Cut', 'Scalp Spa'],
    },
    {
      "name": "Scissors Palace",
      "category": "barber",
      "location": const LatLng(3.1450, 101.7000), // KL
      "rating": 4.3,
      "reviews": 85,
      "openHour": 11, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Quick Cut', 'Shave'],
    },
    {
      "name": "Bangi Mobile Cuts",
      "category": "barber",
      "location": const LatLng(2.9250, 101.7700), // Bangi
      "rating": 4.9,
      "reviews": 99,
      "openHour": 10, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['Home Barbering', 'Kids House Call'],
      "isMobileService": true,
    },
    {
      "name": "Damansara Dapper",
      "category": "barber",
      "location": const LatLng(3.1300, 101.6200), // Damansara
      "rating": 4.7,
      "reviews": 320,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Premium Fade', 'Hot Towel', 'Massage'],
    },
    {
      "name": "Bukit Bintang Elite Salon",
      "category": "salon",
      "location": const LatLng(3.1466, 101.7112),
      "rating": 4.8,
      "reviews": 412,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Digital Perm', 'Keratin Treatment', 'Hair Styling'],
      "recentReviews": [{'userName': 'Sarah', 'rating': 5, 'comment': 'Love the ambiance and service!'}]
    },
    {
      "name": "Ampang Grooming Lounge",
      "category": "barber",
      "location": const LatLng(3.1496, 101.7618),
      "rating": 4.6,
      "reviews": 234,
      "openHour": 11, "openMinute": 0, "closeHour": 21, "closeMinute": 30,
      "services": ['Gentleman Cut', 'Beard Trim', 'Hot Towel'],
    },
    {
      "name": "Cheras Mobile Stylist",
      "category": "salon",
      "location": const LatLng(3.1065, 101.7275),
      "rating": 4.9,
      "reviews": 105,
      "openHour": 9, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['House Call Blowout', 'Home Hair Color', 'Trimming'],
      "isMobileService": true,
    },
    {
      "name": "Klang Classic Barbers",
      "category": "barber",
      "location": const LatLng(3.0360, 101.4433),
      "rating": 4.5,
      "reviews": 312,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Classic Taper', 'Straight Razor Shave'],
    },
    {
      "name": "Petaling Jaya Cuts",
      "category": "barber",
      "location": const LatLng(3.1073, 101.6067),
      "rating": 4.7,
      "reviews": 450,
      "openHour": 10, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Modern Fade', 'Line Up', 'Hair Wash'],
    },
    {
      "name": "Puchong House Call Barber",
      "category": "barber",
      "location": const LatLng(3.0310, 101.6168),
      "rating": 5.0,
      "reviews": 75,
      "openHour": 15, "openMinute": 0, "closeHour": 23, "closeMinute": 59,
      "services": ['Late Night Cut', 'VIP Mobile Grooming'],
      "isMobileService": true,
    },
    {
      "name": "Setia Alam Premium Hair Spa",
      "category": "salon",
      "location": const LatLng(3.0970, 101.4623),
      "rating": 4.6,
      "reviews": 298,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Scalp Massage', 'Hair Spa', 'Cut & Wash'],
    },
    {
      "name": "Wangsa Maju Dapper Cuts",
      "category": "barber",
      "location": const LatLng(3.2039, 101.7371),
      "rating": 4.4,
      "reviews": 167,
      "openHour": 11, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Student Cut', 'Pompadour', 'Shaving'],
    },

    // --- NORTHERN REGION (PENANG, KEDAH, PERLIS, PERAK) ---
    {
      "name": "Bayan Lepas Mobile Fade",
      "category": "barber",
      "location": const LatLng(5.2954, 100.2573),
      "rating": 4.8,
      "reviews": 110,
      "openHour": 9, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Office Call Haircut', 'Quick Trim'],
      "isMobileService": true,
    },
    {
      "name": "Butterworth Barber Studio",
      "category": "barber",
      "location": const LatLng(5.3957, 100.3705),
      "rating": 4.5,
      "reviews": 213,
      "openHour": 10, "openMinute": 30, "closeHour": 20, "closeMinute": 30,
      "services": ['Scissor Cut', 'Beard Styling'],
    },
    {
      "name": "Langkawi Gentlemen's Cave",
      "category": "barber",
      "location": const LatLng(6.3265, 99.8432),
      "rating": 4.7,
      "reviews": 320,
      "openHour": 12, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['Tourist Special Cut', 'Island Fade', 'Beard Trim'],
      "recentReviews": [{'userName': 'John', 'rating': 5, 'comment': 'Best haircut on the island.'}]
    },
    {
      "name": "Sungai Petani Salon & Spa",
      "category": "salon",
      "location": const LatLng(5.6429, 100.4908),
      "rating": 4.4,
      "reviews": 185,
      "openHour": 10, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Hair Treatment', 'Trimming', 'Rebonding'],
    },
    {
      "name": "Kangar Street Barber",
      "category": "barber",
      "location": const LatLng(6.4389, 100.1944),
      "rating": 4.3,
      "reviews": 95,
      "openHour": 9, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Traditional Cut', 'Shave'],
    },
    {
      "name": "Arau Mobile Stylist",
      "category": "salon",
      "location": const LatLng(6.4297, 100.2698),
      "rating": 4.9,
      "reviews": 45,
      "openHour": 9, "openMinute": 0, "closeHour": 17, "closeMinute": 0,
      "services": ['Home Hair Spa', 'Makeup'],
      "isMobileService": true,
    },
    {
      "name": "Sitiawan Vintage Cuts",
      "category": "barber",
      "location": const LatLng(4.2120, 100.6991),
      "rating": 4.6,
      "reviews": 134,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Pompadour', 'Classic Fade', 'Hot Towel'],
    },
    {
      "name": "Teluk Intan Hair & Beauty",
      "category": "salon",
      "location": const LatLng(4.0259, 101.0213),
      "rating": 4.5,
      "reviews": 150,
      "openHour": 10, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Coloring', 'Hair Wash', 'Styling'],
    },
    {
      "name": "Seri Iskandar Mobile Grooming",
      "category": "barber",
      "location": const LatLng(4.3644, 100.9806),
      "rating": 4.8,
      "reviews": 88,
      "openHour": 14, "openMinute": 0, "closeHour": 23, "closeMinute": 0,
      "services": ['University House Call', 'Student Fade'],
      "isMobileService": true,
    },

    // --- SOUTHERN REGION (JOHOR, MELAKA, NEGERI SEMBILAN) ---
    {
      "name": "Batu Pahat Sharp Fades",
      "category": "barber",
      "location": const LatLng(1.8494, 102.9288),
      "rating": 4.5,
      "reviews": 210,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Skin Fade', 'Line Up', 'Shaving'],
    },
    {
      "name": "Muar Mobile Salon",
      "category": "salon",
      "location": const LatLng(2.0494, 102.5684),
      "rating": 4.7,
      "reviews": 60,
      "openHour": 10, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Mobile Wash & Blow', 'Trimming'],
      "isMobileService": true,
    },
    {
      "name": "Kulai Barber Cartel",
      "category": "barber",
      "location": const LatLng(1.6575, 103.6053),
      "rating": 4.6,
      "reviews": 180,
      "openHour": 11, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Taper Fade', 'Beard Grooming'],
    },
    {
      "name": "Ayer Keroh Hair Studio",
      "category": "salon",
      "location": const LatLng(2.2687, 102.2858),
      "rating": 4.4,
      "reviews": 142,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Hair Treatment', 'Coloring', 'Curling'],
    },
    {
      "name": "Jasin House Call Barber",
      "category": "barber",
      "location": const LatLng(2.3090, 102.4316),
      "rating": 4.9,
      "reviews": 34,
      "openHour": 8, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Mobile Grooming', 'Kids Cut'],
      "isMobileService": true,
    },
    {
      "name": "Port Dickson Gentleman Cuts",
      "category": "barber",
      "location": const LatLng(2.5228, 101.7958),
      "rating": 4.5,
      "reviews": 110,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Beach Ready Fade', 'Beard Trim'],
    },
    {
      "name": "Nilai Salon Hub",
      "category": "salon",
      "location": const LatLng(2.8166, 101.7981),
      "rating": 4.6,
      "reviews": 230,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Balayage', 'Hair Spa', 'Cut & Wash'],
    },
    {
      "name": "Sendayan Mobile Haircut",
      "category": "barber",
      "location": const LatLng(2.6842, 101.8791),
      "rating": 4.8,
      "reviews": 92,
      "openHour": 18, "openMinute": 0, "closeHour": 23, "closeMinute": 59,
      "services": ['Night Call Cut', 'Line Up'],
      "isMobileService": true,
    },

    // --- EAST COAST (PAHANG, TERENGGANU, KELANTAN) ---
    {
      "name": "Temerloh Barber Connect",
      "category": "barber",
      "location": const LatLng(3.4485, 102.4176),
      "rating": 4.5,
      "reviews": 124,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Classic Trim', 'Shave'],
    },
    {
      "name": "Cameron Highlands Salon",
      "category": "salon",
      "location": const LatLng(4.4721, 101.3801),
      "rating": 4.7,
      "reviews": 85,
      "openHour": 9, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Wash & Blow', 'Hair Treatment'],
    },
    {
      "name": "Bentong Mobile Barber",
      "category": "barber",
      "location": const LatLng(3.5222, 101.9103),
      "rating": 4.9,
      "reviews": 40,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['House Call Haircut', 'Kids Cut'],
      "isMobileService": true,
    },
    {
      "name": "Kemaman Hair & Co.",
      "category": "salon",
      "location": const LatLng(4.2346, 103.3255),
      "rating": 4.6,
      "reviews": 115,
      "openHour": 10, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Hair Spa', 'Coloring'],
    },
    {
      "name": "Dungun Classic Barbershop",
      "category": "barber",
      "location": const LatLng(4.7570, 103.4116),
      "rating": 4.4,
      "reviews": 80,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Standard Cut', 'Hot Towel'],
    },
    {
      "name": "Pasir Mas Sharp Barber",
      "category": "barber",
      "location": const LatLng(6.0416, 102.1396),
      "rating": 4.5,
      "reviews": 102,
      "openHour": 9, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Skin Fade', 'Line Up'],
    },
    {
      "name": "Machang Mobile Beauty",
      "category": "salon",
      "location": const LatLng(5.7645, 102.2155),
      "rating": 4.8,
      "reviews": 55,
      "openHour": 9, "openMinute": 0, "closeHour": 17, "closeMinute": 0,
      "services": ['Home Hair Care', 'Styling'],
      "isMobileService": true,
    },

    // --- EAST MALAYSIA (SABAH, SARAWAK, LABUAN) ---
    {
      "name": "Sandakan Fade Masters",
      "category": "barber",
      "location": const LatLng(5.8402, 118.1179),
      "rating": 4.6,
      "reviews": 230,
      "openHour": 9, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Burst Fade', 'Beard Sculpting'],
    },
    {
      "name": "Tawau Mobile Hair Expert",
      "category": "salon",
      "location": const LatLng(4.2448, 117.8912),
      "rating": 4.9,
      "reviews": 88,
      "openHour": 8, "openMinute": 0, "closeHour": 18, "closeMinute": 0,
      "services": ['Mobile Wash & Blow', 'Coloring'],
      "isMobileService": true,
    },
    {
      "name": "Miri Urban Salon",
      "category": "salon",
      "location": const LatLng(4.3995, 113.9914),
      "rating": 4.5,
      "reviews": 190,
      "openHour": 10, "openMinute": 0, "closeHour": 20, "closeMinute": 0,
      "services": ['Rebonding', 'Hair Treatment', 'Trim'],
    },
    {
      "name": "Sibu Gentlemen Barbers",
      "category": "barber",
      "location": const LatLng(2.2873, 111.8305),
      "rating": 4.4,
      "reviews": 140,
      "openHour": 9, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Classic Cut', 'Straight Razor Shave'],
    },
    {
      "name": "Bintulu Mobile Fadez",
      "category": "barber",
      "location": const LatLng(3.1738, 113.0360),
      "rating": 4.8,
      "reviews": 75,
      "openHour": 15, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['House Call Trim', 'Executive Fade'],
      "isMobileService": true,
    },
    {
      "name": "Labuan Hair Studio",
      "category": "salon",
      "location": const LatLng(5.2831, 115.2308),
      "rating": 4.6,
      "reviews": 110,
      "openHour": 10, "openMinute": 0, "closeHour": 19, "closeMinute": 0,
      "services": ['Hair Spa', 'Cut & Wash'],
    },
    {
      "name": "Inanam Express Cuts",
      "category": "barber",
      "location": const LatLng(5.9890, 116.1422),
      "rating": 4.5,
      "reviews": 150,
      "openHour": 10, "openMinute": 0, "closeHour": 21, "closeMinute": 0,
      "services": ['Quick Trim', 'Kids Cut'],
    },
    {
      "name": "Samarahan Premium Barbershop",
      "category": "barber",
      "location": const LatLng(1.4619, 110.4674),
      "rating": 4.7,
      "reviews": 210,
      "openHour": 11, "openMinute": 0, "closeHour": 22, "closeMinute": 0,
      "services": ['Pompadour', 'Hot Towel Treatment', 'Hair Tattoo'],
    }
  ];
}