import type { InitialState } from "../types";

export const browserFixture: InitialState = {
  apiVersion: 1,
  locale: "en",
  framework: "browser",
  categories: [
    { id: "emergency_medical", icon: "heart-pulse", name: "Emergency Medical", names: { en: "Emergency Medical", de: "Rettungsdienst" }, keywords: ["hospital", "ems"], hasRequestTemplates: true, requestCompetition: true },
    { id: "taxi_transport", icon: "car-taxi-front", name: "Taxi & Transport", names: { en: "Taxi & Transport", de: "Taxi & Transport" }, keywords: ["ride", "cab"], hasRequestTemplates: true, requestCompetition: true },
    { id: "vehicle_services", icon: "wrench", name: "Vehicle Services", names: { en: "Vehicle Services", de: "Fahrzeugservice" }, keywords: ["repair", "mechanic"], hasRequestTemplates: true, requestCompetition: false },
    { id: "restaurants_food", icon: "utensils", name: "Restaurants & Food", names: { en: "Restaurants & Food", de: "Restaurants & Essen" }, keywords: ["food", "order"], hasRequestTemplates: true, requestCompetition: false }
  ],
  companies: [
    { id: "pillbox", displayName: "Pillbox Medical Center", logo: "./icon.svg", backgroundImage: "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=700&q=80", categoryId: "emergency_medical", categoryName: "Emergency Medical", description: "Emergency care and medical assistance.", location: "Pillbox Hill", openingHours: "24/7", keywords: ["hospital", "doctor"], available: true, requestsEnabled: false, messagesEnabled: true, dispatchMode: "ring_all", requestNotificationActionable: false, primaryNumber: "912", numbers: [{ id: "pillbox-main", label: "Emergency", number: "912", distribution: "ring_all", sharedInbox: true, enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, publicVisible: true, available: true }], version: 1 },
    { id: "downtown-cab", displayName: "Downtown Cab Co.", logo: "./icon.svg", backgroundImage: "https://images.unsplash.com/photo-1515569067071-ec3b51335dd0?auto=format&fit=crop&w=700&q=80", categoryId: "taxi_transport", categoryName: "Taxi & Transport", description: "Reliable rides across Los Santos.", location: "East Vinewood", openingHours: "06:00 - 02:00", keywords: ["taxi", "ride"], available: true, requestsEnabled: true, messagesEnabled: true, dispatchMode: "dispatch_only", requestNotificationActionable: true, primaryNumber: "5550100", numbers: [{ id: "taxi-main", label: "Dispatch", number: "5550100", distribution: "dispatch_only", sharedInbox: true, enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, publicVisible: true, available: true }], version: 1 },
    { id: "yellow-jack", displayName: "Yellow Jack Transport", logo: "./icon.svg", backgroundImage: "https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?auto=format&fit=crop&w=700&q=80", categoryId: "taxi_transport", categoryName: "Taxi & Transport", description: "Passenger transport and scheduled rides.", location: "Sandy Shores", openingHours: "08:00 - 22:00", keywords: ["taxi", "transport"], available: true, requestsEnabled: true, messagesEnabled: true, dispatchMode: "random", requestNotificationActionable: true, primaryNumber: "5550110", numbers: [{ id: "yellow-jack-main", label: "Main Line", number: "5550110", distribution: "ring_all", sharedInbox: true, enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, publicVisible: true, available: true }], version: 1 },
    { id: "bennys", displayName: "Benny's Motorworks", logo: "./icon.svg", backgroundImage: "https://images.unsplash.com/photo-1487754180451-c456f719a1fc?auto=format&fit=crop&w=700&q=80", categoryId: "vehicle_services", categoryName: "Vehicle Services", description: "Repairs, tuning and roadside assistance.", location: "Strawberry", openingHours: "10:00 - 23:00", keywords: ["mechanic", "tuning"], available: false, requestsEnabled: true, messagesEnabled: true, dispatchMode: "ring_all", requestNotificationActionable: false, primaryNumber: "5550200", numbers: [{ id: "bennys-main", label: "Workshop", number: "5550200", distribution: "ring_all", sharedInbox: true, enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, publicVisible: true, available: false }], version: 1 }
  ],
  currentUser: {
    source: 12,
    name: "Jordan Reed",
    isServerAdmin: true,
    employment: { companyId: "downtown-cab", companyName: "Downtown Cab Co.", isLeader: true, onDuty: false, employee: null, activeEmployees: [] }
  },
  settings: { directoryTitle: "Los Santos Services", callsEnabled: true, requestsEnabled: true }
};
