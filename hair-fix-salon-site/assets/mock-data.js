/*
 * Fictional development data shaped like the future API responses.
 * Property names intentionally match the identifiers in API_CONTRACT.md.
 */
window.HAIR_FIX_MOCK_DATA = Object.freeze({
  location: {
    locationId: 1,
    salonName: 'Hair Fix Salon',
    timeZone: 'America/New_York'
  },
  services: [
    { serviceId: 1, serviceName: 'Signature Cut', category: 'cut', description: 'Consultation, shampoo, tailored cut, and finish.', price: 45, durationMinutes: 45, isActive: true },
    { serviceId: 2, serviceName: 'Clipper Cut', category: 'cut', description: 'Precision clipper work, shape-up, and styling.', price: 35, durationMinutes: 35, isActive: true },
    { serviceId: 3, serviceName: 'Silk Press', category: 'style', description: 'Cleanse, conditioning treatment, press, and finish.', price: 80, durationMinutes: 90, isActive: true },
    { serviceId: 4, serviceName: 'Protective Style', category: 'style', description: 'Consultation and protective styling customized to you.', price: 120, durationMinutes: 180, isActive: true },
    { serviceId: 5, serviceName: 'Color Refresh', category: 'color', description: 'Tone and refresh existing color with a polished finish.', price: 95, durationMinutes: 120, isActive: true },
    { serviceId: 6, serviceName: 'Beard Detail', category: 'style', description: 'Shape, line, and finish with hot towel treatment.', price: 30, durationMinutes: 30, isActive: true }
  ],
  staff: [
    { staffId: 1, userId: 101, displayName: 'Maya Brooks', specialty: 'Cuts and grooming', isActive: true, serviceIds: [1, 2, 6] },
    { staffId: 2, userId: 102, displayName: 'Jordan Lee', specialty: 'Styling', isActive: true, serviceIds: [1, 3, 4] },
    { staffId: 3, userId: 103, displayName: 'Alex Rivera', specialty: 'Color', isActive: true, serviceIds: [1, 3, 5] }
  ],
  availability: [
    { startTime: '09:00', displayTime: '9:00 AM' },
    { startTime: '11:00', displayTime: '11:00 AM' },
    { startTime: '14:15', displayTime: '2:15 PM' },
    { startTime: '16:30', displayTime: '4:30 PM' }
  ]
});

