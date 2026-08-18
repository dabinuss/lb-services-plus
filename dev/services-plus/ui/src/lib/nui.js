// Thin wrapper around the globals lb-phone injects into a custom app's
// iframe (see docs.lbscripts.com/phone/custom-apps and client/main.lua on
// the Lua side). Falls back to small in-memory fixtures when running via
// `npm run dev` in a plain browser tab, so the UI is iterable without a
// running FiveM server.

export const devMode = !window.invokeNative

// Mirrors the server's authoritative company-branding check so admins get
// immediate feedback before a save. This is intentionally validation, not
// a domain allowlist: any well-formed public HTTPS host is accepted.
export function isValidBrandingUrl(value) {
  const candidate = value?.trim() || ''
  if (!candidate) return true
  if (candidate.length > 255 || /\s/.test(candidate)) return false

  try {
    const url = new URL(candidate)
    if (url.protocol !== 'https:' || url.username || url.password || url.hostname.startsWith('[')) return false

    const hostname = url.hostname.toLowerCase()
    if (hostname === 'localhost' || hostname.endsWith('.localhost') || hostname.endsWith('.local')) return false

    const octets = hostname.split('.').map(Number)
    const isIpv4 = octets.length === 4 && octets.every((part, i) => String(part) === hostname.split('.')[i] && part >= 0 && part <= 255)
    if (isIpv4) {
      const [a, b] = octets
      return !(
        a === 0 || a === 10 || a === 127 || a >= 224
        || (a === 100 && b >= 64 && b <= 127)
        || (a === 169 && b === 254)
        || (a === 172 && b >= 16 && b <= 31)
        || (a === 192 && b === 168)
        || (a === 198 && (b === 18 || b === 19))
      )
    }

    const labels = hostname.split('.')
    return labels.length > 1 && labels.every((label) => /^[a-z0-9-]{1,63}$/.test(label) && !label.startsWith('-') && !label.endsWith('-'))
  } catch {
    return false
  }
}

// Mirrors Config.PageSize.* in shared/config.lua (all 25 there too) - lets
// devMode actually exercise "Load more" instead of always handing back
// every fixture row regardless of `page`.
const FIXTURE_PAGE_SIZE = 25
const paginate = (list, page) => list.slice((page || 0) * FIXTURE_PAGE_SIZE, ((page || 0) + 1) * FIXTURE_PAGE_SIZE)

// One company per category, each with its own background banner, so the
// Services overview/CompanyCard/dashboard-header blur treatment all have
// something real to render against instead of just the plain fallback
// gradient. Picsum's seeded URLs (not real photos of the theme) are used
// deliberately - reliably valid images every time beats a photo-accurate
// but potentially-dead specific Unsplash id, and this data never ships
// (devMode only).
const bg = (seed) => `https://picsum.photos/seed/${seed}/800/450`
const requestTypeIdentifier = (name) => name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'request_type'

const fixtures = {
  bootstrap: {
    categories: [
      { id: 1, key: 'police', name: 'Police', icon: 'police', sort_order: 10 },
      { id: 2, key: 'medical', name: 'Medical', icon: 'medical', sort_order: 20 },
      { id: 3, key: 'taxi', name: 'Taxi', icon: 'taxi', sort_order: 30 },
      { id: 4, key: 'mechanic', name: 'Mechanic', icon: 'wrench', sort_order: 40 },
      { id: 5, key: 'news', name: 'News', icon: 'news', sort_order: 70 },
    ],
    companies: [
      {
        id: 1,
        job: 'police',
        name: 'Los Santos Police Department',
        categoryId: 1,
        icon: 'https://cdn-icons-png.flaticon.com/512/7211/7211100.png',
        background: bg('lspd'),
        available: true,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [
          { id: 1, label: 'Main Hotline', number: '911', isMain: true, callsEnabled: true, messagesEnabled: true },
          { id: 7, label: 'Dispatch', number: '5550911', isMain: false, callsEnabled: true, messagesEnabled: true },
        ],
      },
      {
        id: 2,
        job: 'ambulance',
        name: 'Pillbox Medical',
        categoryId: 2,
        icon: 'https://cdn-icons-png.flaticon.com/128/1032/1032989.png',
        background: bg('pillbox'),
        available: false,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [{ id: 2, label: 'Main Hotline', number: '911', isMain: true, callsEnabled: true, messagesEnabled: true }],
      },
      {
        id: 3,
        job: 'mechanic',
        name: 'Downtown Cab Co.',
        categoryId: 4,
        icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png',
        // 'downtown-cab' happened to be an almost pure-white picsum photo
        // (avg rgb ~241,241,241) - made the blurred dashboard header look
        // like a plain white fadeout with no visible image underneath it,
        // which read as a CSS bug but was actually just this fixture's
        // source photo. 'taxi-rank' has real color/contrast.
        background: bg('taxi-rank'),
        available: true,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [
          { id: 3, label: 'Main Hotline', number: '911', isMain: true, callsEnabled: true, messagesEnabled: true },
          { id: 4, label: 'Workshop', number: '5550199', isMain: false, callsEnabled: true, messagesEnabled: true },
        ],
      },
      {
        id: 4,
        job: 'taxi',
        name: 'Coastal Taxi Co.',
        categoryId: 3,
        icon: 'https://cdn-icons-png.flaticon.com/128/3079/3079165.png',
        background: bg('coastal-taxi'),
        available: true,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [
          { id: 5, label: 'Main Hotline', number: '5550188', isMain: true, callsEnabled: true, messagesEnabled: true },
          { id: 6, label: 'Airport Line', number: '5550177', isMain: false, callsEnabled: true, messagesEnabled: true },
        ],
      },
    ],
    myNumber: '5550100',
    admin: true,
    // Logged in at the Mechanic company (Downtown Cab Co., id 3) - referenced
    // by companyLogin/getTeam/getCompanyConversations/etc. below too, keep
    // any future id changes here in sync with those.
    employee: {
      memberId: 1,
      companyId: 3,
      job: 'mechanic',
      jobLabel: 'Mechanic',
      grade: 4,
      gradeLabel: 'Boss',
      isBoss: true,
      onDuty: true,
      status: 'available',
    },
  },
  // Customer-facing request types, keyed by categoryId - one per category so
  // the Request sheet has something to show no matter which company it's
  // opened from.
  requestTypes: {
    4: [
      {
        id: 1, category_id: 4, name: 'Roadside Assistance', icon: 'roadside_assistance',
        description: 'Request on-site repairs.', passenger_count: 0, passenger_mode: 'disabled', description_enabled: 1, note_mode: 'required',
      },
    ],
    3: [
      {
        id: 2, category_id: 3, name: 'Taxi Pickup', icon: 'taxi_pickup',
        description: 'Request a ride from your current location.', passenger_count: 1, passenger_mode: 'required', count_label: 'Passenger count', description_enabled: 1, note_mode: 'optional',
      },
    ],
    1: [
      {
        id: 3, category_id: 1, name: 'Request Backup', icon: 'request_backup',
        description: 'Flag down the nearest available unit.', passenger_count: 0, passenger_mode: 'disabled', description_enabled: 1, note_mode: 'optional',
      },
    ],
    2: [
      {
        id: 4, category_id: 2, name: 'Medical Emergency', icon: 'medical_emergency',
        description: 'Request an ambulance to your location.', passenger_count: 1, passenger_mode: 'required', count_label: 'Number of injured people', description_enabled: 0, note_mode: 'disabled',
      },
    ],
    5: [
      {
        id: 5, category_id: 5, name: 'Breaking News', icon: 'breaking_news',
        description: 'Report breaking news at your current location.', passenger_count: 0,
        passenger_mode: 'disabled', description_enabled: 0, note_mode: 'disabled',
      },
    ],
  },
}

// Single demo conversation (channelId 1, customer 5550100 <-> Downtown Cab's
// Main Hotline) - deliberately long (30+) so "Load older" on scroll-to-top
// actually has something to page through. Every fixture channel_id resolves
// to this same conversation regardless of which one was clicked (a real
// per-channel message store is more than this fixture layer needs to be).
let fixtureMessages = Array.from({ length: 32 }, (_, i) => {
  const fromCustomer = i % 3 !== 2 // mostly customer, company chimes in every third message
  return {
    id: i + 1,
    sender: fromCustomer ? '5550100' : '5559001',
    sender_type: fromCustomer ? 'customer' : 'company',
    content: fromCustomer
      ? ['Hey, is anyone there?', 'Still waiting on a pickup', 'Any update?', 'Ok thanks', 'How much longer?'][i % 5]
      : ["We're on it, hang tight!", 'On our way now.', 'Should be about 5 more minutes.', 'Thanks for your patience!'][i % 4],
    created_at: new Date(Date.now() - (32 - i) * 90000).toISOString(),
  }
})

// Own conversations across every company, for Activity > Messages.
let fixtureActivity = [
  {
    channel_id: 1,
    last_message: 'Thanks for your patience!',
    updated_at: new Date(Date.now() - 60000).toISOString(),
    company: { id: 3, name: 'Downtown Cab Co.', icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png' },
  },
  {
    channel_id: 2,
    last_message: 'Backup unit dispatched to your location.',
    updated_at: new Date(Date.now() - 3 * 3600000).toISOString(),
    company: { id: 1, name: 'Los Santos Police Department', icon: 'https://cdn-icons-png.flaticon.com/512/7211/7211100.png' },
  },
  {
    channel_id: 3,
    last_message: 'Ambulance is en route, ETA 4 minutes.',
    updated_at: new Date(Date.now() - 26 * 3600000).toISOString(),
    company: { id: 2, name: 'Pillbox Medical', icon: 'https://cdn-icons-png.flaticon.com/128/1032/1032989.png' },
  },
  {
    channel_id: 4,
    last_message: 'Your driver is 2 minutes away.',
    updated_at: new Date(Date.now() - 2 * 86400000).toISOString(),
    company: { id: 4, name: 'Coastal Taxi Co.', icon: 'https://cdn-icons-png.flaticon.com/128/3079/3079165.png' },
  },
]

// Own requests across companies/types/every status, for Activity > Requests
// and the company dashboard's own Requests queue.
let fixtureRequests = [
  {
    id: 1, status: 'open', request_type_id: 2, company_id: null, passenger_count: 2, description: 'Alta Street',
    type_name: 'Taxi Pickup', type_icon: 'taxi', is_mine: false, pos_x: 100, pos_y: 200,
    created_at: new Date(Date.now() - 30000).toISOString(),
  },
  {
    id: 2, status: 'active', request_type_id: 1, company_id: 3, passenger_count: null, description: 'Flat tire on the highway',
    type_name: 'Roadside Assistance', type_icon: 'wrench', is_mine: true, pos_x: 220, pos_y: -340,
    created_at: new Date(Date.now() - 600000).toISOString(),
  },
  {
    id: 3, status: 'completed', request_type_id: 1, company_id: 3, passenger_count: null, description: null,
    type_name: 'Roadside Assistance', type_icon: 'wrench', is_mine: true, pos_x: 50, pos_y: 60,
    created_at: new Date(Date.now() - 5 * 3600000).toISOString(),
  },
  {
    id: 4, status: 'cancelled', request_type_id: 2, company_id: 4, passenger_count: 1, description: 'Airport terminal 2',
    type_name: 'Taxi Pickup', type_icon: 'taxi', is_mine: false, pos_x: -800, pos_y: -1200,
    created_at: new Date(Date.now() - 30 * 3600000).toISOString(),
  },
  {
    id: 5, status: 'completed', request_type_id: 2, company_id: 3, passenger_count: 1, description: null,
    type_name: 'Taxi Pickup', type_icon: 'taxi', is_mine: true, pos_x: 300, pos_y: 400,
    feature_data: { feature: 'taxi_pricing', billingMode: 'per_100m', rate: 2, metric: 850, amount: 17 },
    created_at: new Date(Date.now() - 2 * 3600000).toISOString(),
  },
]

// Own call history across companies/states, for Activity > Calls.
const fixtureCalls = [
  {
    id: 1, customer_number: '5559876', state: 'missed', label: 'Main Hotline',
    company_id: 3, number_id: 3,
    company_name: 'Downtown Cab Co.', company_icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png',
    created_at: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: 2, customer_number: '5550100', state: 'answered', label: 'Main Hotline',
    company_id: 1, number_id: 1,
    company_name: 'Los Santos Police Department', company_icon: 'https://cdn-icons-png.flaticon.com/512/7211/7211100.png',
    created_at: new Date(Date.now() - 7 * 3600000).toISOString(),
  },
  {
    id: 3, customer_number: '5550100', state: 'ringing', label: 'Main Hotline',
    company_id: 2, number_id: 2,
    company_name: 'Pillbox Medical', company_icon: 'https://cdn-icons-png.flaticon.com/128/1032/1032989.png',
    created_at: new Date(Date.now() - 20 * 60000).toISOString(),
  },
  {
    id: 4, customer_number: '5550100', state: 'answered', label: 'Airport Line',
    company_id: 4, number_id: 6,
    company_name: 'Coastal Taxi Co.', company_icon: 'https://cdn-icons-png.flaticon.com/128/3079/3079165.png',
    created_at: new Date(Date.now() - 3 * 86400000).toISOString(),
  },
]

let fixtureHotlines = [
  { numberId: 3, label: 'Main Hotline', number: '555-0100', active: true, locked: false },
  { numberId: 4, label: 'Workshop', number: '555-0200', active: false, locked: false },
]

// Team roster for the logged-in company (Downtown Cab, mechanic) - getTeam()
// is always scoped to the caller's own company, so this is the only one
// that needs filling out. A few members with varied grade/status/hotlines
// to actually exercise the search bar and list.
const fixtureTeam = [
  { memberId: 1, name: 'Dabi', gradeLabel: 'Boss', status: 'available', hotlines: ['Main Hotline'], phoneNumber: '5559001' },
  { memberId: 2, name: 'John', gradeLabel: 'Worker', status: 'busy', hotlines: ['Main Hotline', 'Workshop'], phoneNumber: '5559002' },
  { memberId: 3, name: 'Mia Torres', gradeLabel: 'Senior Mechanic', status: 'pause', hotlines: ['Workshop'], phoneNumber: '5559003' },
  { memberId: 4, name: 'Tom Reyes', gradeLabel: 'Mechanic', status: 'available', hotlines: ['Main Hotline'], phoneNumber: '5559004' },
]

let fixtureServiceSettings = { activeRequestDisconnectGraceMinutes: 5 }

let fixtureSettings = {
  callsEnabled: true, messagesEnabled: true, requestsEnabled: true,
  adminCallsAllowed: true, adminMessagesAllowed: true, adminRequestsAllowed: true,
  callRouting: 'all', requestRouting: 'all',
  numbers: [
    { id: 3, label: 'Main Hotline', isMain: true, callsEnabled: true, messagesEnabled: true, mailboxEnabled: true },
    { id: 4, label: 'Workshop', isMain: false, callsEnabled: true, messagesEnabled: true, mailboxEnabled: true },
  ],
}

// Mirrors what server/taxi_pricing.lua's getTaxiPricingSettings returns for
// a company whose category has a taxi_pricing-enabled request type -
// request type 2 (Taxi Pickup) above is the only one flagged for it.
let fixtureTaxiPricing = [
  { requestTypeId: 2, requestTypeName: 'Taxi Pickup', billingMode: 'per_100m', rate: 2 },
]

// Employee-side inbox for the logged-in company - a few conversations from
// different contact numbers so the list (and its own pagination) has
// something to show beyond one row.
let fixtureCompanyConversations = [
  { channel_id: 1, contact_number: '5550100', last_message: 'Thanks for your patience!', label: 'Main Hotline' },
  { channel_id: 5, contact_number: '5551122', last_message: 'Can you fix a flat tire?', label: 'Workshop' },
  { channel_id: 6, contact_number: '5553344', last_message: 'What are your hours?', label: 'Main Hotline' },
]

// --------------------------------------------------------- admin fixtures

// Mirrors Config.DefaultCategories in shared/categories.lua - keep both in
// sync when categories change, this one only feeds the browser-only preview.
// Ids 1-5 are kept stable (fixtureAdminCompanies/fixtureAdminRequestTypes
// below reference them by id, same as real foreign keys would) - sort_order,
// not id, controls display order, exactly like the real DB.
let fixtureAdminCategories = [
  { id: 1, key: 'police', name: 'Law Enforcement', icon: 'police', sort_order: 10, competition_allowed: 0 },
  { id: 2, key: 'medical', name: 'Medical & Hospitals', icon: 'medical', sort_order: 40, competition_allowed: 0 },
  { id: 3, key: 'taxi', name: 'Taxi & Transportation', icon: 'taxi', sort_order: 50, competition_allowed: 1 },
  { id: 4, key: 'mechanic', name: 'Auto Repair Shops', icon: 'wrench', sort_order: 70, competition_allowed: 1 },
  { id: 5, key: 'news', name: 'News & Media', icon: 'news', sort_order: 150, competition_allowed: 0 },
  { id: 6, key: 'government', name: 'Government', icon: 'bank', sort_order: 20, competition_allowed: 0 },
  { id: 7, key: 'law', name: 'Law Firms & Attorneys', icon: 'law', sort_order: 30, competition_allowed: 0 },
  { id: 8, key: 'car_dealer', name: 'Car Dealerships', icon: 'car-dealer', sort_order: 60, competition_allowed: 0 },
  { id: 9, key: 'towing', name: 'Towing Services', icon: 'tow-truck', sort_order: 80, competition_allowed: 1 },
  { id: 10, key: 'carwash', name: 'Car Washes', icon: 'car-wash', sort_order: 90, competition_allowed: 0 },
  { id: 11, key: 'restaurant', name: 'Restaurants & Dining', icon: 'restaurant', sort_order: 100, competition_allowed: 0 },
  { id: 12, key: 'bar', name: 'Clubs & Bars', icon: 'bar', sort_order: 110, competition_allowed: 0 },
  { id: 13, key: 'barber', name: 'Barbershops', icon: 'barber', sort_order: 120, competition_allowed: 0 },
  { id: 14, key: 'tattoo', name: 'Tattoo & Piercing Parlors', icon: 'tattoo', sort_order: 130, competition_allowed: 0 },
  { id: 15, key: 'music', name: 'Record Labels', icon: 'music', sort_order: 140, competition_allowed: 0 },
  { id: 16, key: 'shop', name: 'Retail Stores', icon: 'shop', sort_order: 160, competition_allowed: 0 },
  { id: 17, key: 'community', name: 'Community & Organizations', icon: 'people', sort_order: 170, competition_allowed: 0 },
  { id: 18, key: 'funeral', name: 'Funeral Homes', icon: 'funeral', sort_order: 180, competition_allowed: 0 },
]

// Mirrors fixtures.bootstrap.companies above (same ids/backgrounds) so the
// admin area has all four categories' companies to edit too, not just the
// one the test employee happens to be logged into.
let fixtureAdminCompanies = [
  {
    id: 1, job: 'police', name: 'Los Santos Police Department', category_id: 1, boss_grade: 100, enabled: 1,
    admin_calls_allowed: 1, admin_messages_allowed: 1, admin_requests_allowed: 1,
    icon: 'https://cdn-icons-png.flaticon.com/512/7211/7211100.png', background: bg('lspd'),
    numbers: [
      { id: 1, label: 'Main Hotline', number: '911', is_main: 1, enabled: 1 },
      { id: 7, label: 'Dispatch', number: '5550911', is_main: 0, enabled: 1 },
    ],
  },
  {
    id: 2, job: 'ambulance', name: 'Pillbox Medical', category_id: 2, boss_grade: 100, enabled: 1,
    admin_calls_allowed: 1, admin_messages_allowed: 1, admin_requests_allowed: 1,
    icon: 'https://cdn-icons-png.flaticon.com/128/1032/1032989.png', background: bg('pillbox'),
    numbers: [{ id: 2, label: 'Main Hotline', number: '912', is_main: 1, enabled: 1 }],
  },
  {
    id: 3, job: 'mechanic', name: 'Downtown Cab Co.', category_id: 4, boss_grade: 4, enabled: 1,
    admin_calls_allowed: 1, admin_messages_allowed: 1, admin_requests_allowed: 1,
    icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png', background: bg('taxi-rank'),
    numbers: [
      { id: 3, label: 'Main Hotline', number: '911', is_main: 1, enabled: 1 },
      { id: 4, label: 'Workshop', number: '5550199', is_main: 0, enabled: 1 },
    ],
  },
  {
    id: 4, job: 'taxi', name: 'Coastal Taxi Co.', category_id: 3, boss_grade: 100, enabled: 1,
    admin_calls_allowed: 1, admin_messages_allowed: 1, admin_requests_allowed: 1,
    icon: 'https://cdn-icons-png.flaticon.com/128/3079/3079165.png', background: bg('coastal-taxi'),
    numbers: [
      { id: 5, label: 'Main Hotline', number: '5550188', is_main: 1, enabled: 1 },
      { id: 6, label: 'Airport Line', number: '5550177', is_main: 0, enabled: 1 },
    ],
  },
]

// Mirrors fixtures.requestTypes above, one per category.
let fixtureAdminRequestTypes = [
  {
    id: 1, category_id: 4, name: 'Roadside Assistance', icon: 'roadside_assistance', description: 'Request on-site repairs.',
    passenger_count: 0, passenger_mode: 'disabled', description_enabled: 1, note_mode: 'required', competition_enabled: 0, enabled: 1,
  },
  {
    id: 2, category_id: 3, name: 'Taxi Pickup', icon: 'taxi_pickup', description: 'Request a ride.',
    passenger_count: 1, passenger_mode: 'required', description_enabled: 1, note_mode: 'optional', competition_enabled: 1, enabled: 1,
    feature: 'taxi_pricing',
  },
  {
    id: 3, category_id: 1, name: 'Request Backup', icon: 'request_backup', description: 'Flag down the nearest available unit.',
    passenger_count: 0, passenger_mode: 'disabled', description_enabled: 1, note_mode: 'optional', competition_enabled: 0, enabled: 1,
  },
  {
    id: 4, category_id: 2, name: 'Medical Emergency', icon: 'medical_emergency', description: 'Request an ambulance.',
    passenger_count: 1, passenger_mode: 'required', count_label: 'Number of injured people',
    description_enabled: 0, note_mode: 'disabled', competition_enabled: 0, enabled: 1,
  },
  {
    id: 5, category_id: 5, name: 'Breaking News', icon: 'breaking_news',
    description: 'Report breaking news at your current location.', passenger_count: 0, passenger_mode: 'disabled',
    description_enabled: 0, note_mode: 'disabled', competition_enabled: 0, enabled: 1,
  },
]

async function fetchNuiFixture(action, data) {
  await new Promise((resolve) => setTimeout(resolve, 120))

  switch (action) {
    case 'bootstrap':
      return fixtures.bootstrap
    case 'companyLogin':
      return {
        company: { id: 3, name: 'Downtown Cab Co.', job: 'mechanic', icon: fixtures.bootstrap.companies[2].icon },
        employee: { memberId: 1, name: 'Dabi', grade: 4, gradeLabel: 'Boss', isBoss: true, onDuty: true },
      }
    case 'toggleDuty':
    case 'setStatus':
      return true
    case 'openConversation':
    case 'getMessages': {
      // Newest-first + cursor slice, same as the real `id < beforeId ORDER
      // BY id DESC LIMIT` (plan review round 5 §6) - lets "Load older"
      // (ConversationScreen) actually have something to page through, and
      // mirrors the real callback's `beforeId` contract instead of the old
      // OFFSET-based `page` one. `sender` is dropped from what's returned,
      // same as the real server (plan review round 5 §5) - the UI never
      // reads it.
      const newestFirst = [...fixtureMessages].sort((a, b) => b.id - a.id)
      const slice = data.beforeId ? newestFirst.filter((m) => m.id < data.beforeId) : newestFirst
      const messages = slice.slice(0, FIXTURE_PAGE_SIZE).map(({ sender: _sender, ...rest }) => rest)
      return { channelId: 1, contactNumber: '5550100', viewerRole: 'customer', messages }
    }
    case 'sendMessage': {
      const message = {
        id: fixtureMessages.length + 1, sender: fixtures.bootstrap.myNumber, sender_type: 'customer', content: data.content,
        created_at: new Date(Date.now()).toISOString(),
      }
      fixtureMessages.push(message)
      const { sender: _sender, ...withoutSender } = message
      return withoutSender
    }
    case 'getActivity':
      return paginate(fixtureActivity, data.page)
    case 'archiveConversation':
      return true
    case 'resolveCall': {
      // Main numbers ring the native company ring-group (matches "All"
      // routing on a real server); anything else resolves to one random
      // employee's own number, same as the real resolveCall would.
      const MAIN_NUMBER_JOB = { 1: 'police', 2: 'ambulance', 3: 'mechanic', 5: 'taxi' }
      const job = MAIN_NUMBER_JOB[data.numberId]
      return job ? { company: job } : { number: '5551234' }
    }
    case 'getCallHistory':
    case 'getMyCalls':
      return paginate(fixtureCalls, data.page)
    case 'getHotlines':
      return fixtureHotlines
    case 'toggleHotline':
      fixtureHotlines = fixtureHotlines.map((h) => (h.numberId === data.numberId ? { ...h, active: data.active } : h))
      return { ok: true, hotlines: fixtureHotlines }
    case 'getTeam':
      return fixtureTeam
    case 'getCompanyConversations':
      return paginate(fixtureCompanyConversations, data.page)
    case 'getTaxiPricingSettings':
      return fixtureTaxiPricing
    case 'updateTaxiPricingSettings':
      fixtureTaxiPricing = fixtureTaxiPricing.map((t) =>
        t.requestTypeId === data.requestTypeId ? { ...t, ...data.settings } : t,
      )
      return true
    case 'getCompanySettings':
      return fixtureSettings
    case 'updateCompanySettings': {
      fixtureSettings = { ...fixtureSettings, ...data.settings }
      // Same fixture-sync gap as updateNumberSettings below - the Services
      // overview reads company.callsEnabled/messagesEnabled/requestsEnabled
      // from fixtures.bootstrap.companies, a separate object from
      // fixtureSettings above, so a change here needs mirroring over there
      // too or the overview's buttons never reflect it in devMode.
      const loggedInCompany = fixtures.bootstrap.companies.find((c) => c.id === 3)
      if (loggedInCompany) {
        loggedInCompany.callsEnabled = fixtureSettings.callsEnabled
        loggedInCompany.messagesEnabled = fixtureSettings.messagesEnabled
        loggedInCompany.requestsEnabled = fixtureSettings.requestsEnabled
      }
      return true
    }
    case 'updateNumberSettings': {
      fixtureSettings = {
        ...fixtureSettings,
        numbers: fixtureSettings.numbers.map((n) => {
          if (n.id !== data.numberId) return n
          const next = { ...n, ...data.settings }
          // Mirrors the server: only Calls stays forced on for the main
          // number. One Messages toggle, not a separate Mailbox one -
          // mailboxEnabled always follows messagesEnabled (server/main.lua).
          next.callsEnabled = n.isMain || next.callsEnabled
          next.mailboxEnabled = next.messagesEnabled
          return next
        }),
      }
      // The Services overview (CompanyCard's Call/Message buttons) reads
      // its own copy of this number from fixtures.bootstrap.companies, not
      // from fixtureSettings above - two separate fixture datasets standing
      // in for what's really the same DB row in production. Without this,
      // a Settings change here would never show up over there in devMode.
      const updated = fixtureSettings.numbers.find((n) => n.id === data.numberId)
      if (updated) {
        fixtures.bootstrap.companies.forEach((c) => {
          c.numbers = c.numbers.map((n) =>
            n.id === data.numberId ? { ...n, callsEnabled: updated.callsEnabled, messagesEnabled: updated.messagesEnabled } : n,
          )
        })
      }
      return true
    }
    case 'getRequestTypes':
      return fixtures.requestTypes[data.categoryId] || []
    case 'createRequest':
      return { id: fixtureRequests.length + 1, reached: true }
    case 'acceptRequest':
      fixtureRequests = fixtureRequests.map((r) => (r.id === data.requestId ? { ...r, status: 'active', is_mine: true } : r))
      return { requestId: data.requestId, typeName: 'Taxi Pickup', companyName: 'Downtown Cab Co.', x: 100, y: 200 }
    case 'completeRequest':
      fixtureRequests = fixtureRequests.map((r) => (r.id === data.requestId ? { ...r, status: 'completed' } : r))
      return true
    case 'cancelRequest':
      fixtureRequests = fixtureRequests.map((r) => (r.id === data.requestId ? { ...r, status: 'cancelled' } : r))
      return true
    case 'getCompanyRequests':
      return paginate(fixtureRequests, data.page)
    case 'getMyRequests':
      return paginate(
        fixtureRequests.map((r) => {
          const company = fixtures.bootstrap.companies.find((c) => c.id === r.company_id)
          return { ...r, company_name: company?.name, company_icon: company?.icon }
        }),
        data.page,
      )
    case 'setWaypoint':
      console.log('[dev] setWaypoint', data)
      return true

    // -- admin --------------------------------------------------------
    case 'admin:getServiceSettings':
      return fixtureServiceSettings
    case 'admin:updateServiceSettings':
      fixtureServiceSettings = { ...fixtureServiceSettings, ...data }
      return true
    case 'admin:getCategories':
      return fixtureAdminCategories
    case 'admin:createCategory':
      fixtureAdminCategories = [
        ...fixtureAdminCategories,
        { id: fixtureAdminCategories.length + 1, sort_order: data.sort, competition_allowed: data.competitionAllowed ? 1 : 0, ...data },
      ]
      return true
    case 'admin:updateCategory':
      fixtureAdminCategories = fixtureAdminCategories.map((c) =>
        c.id === data.id ? { ...c, ...data, sort_order: data.sort, competition_allowed: data.competitionAllowed ? 1 : 0 } : c,
      )
      return true
    case 'admin:deleteCategory':
      if (
        fixtureAdminCompanies.some((c) => c.category_id === data.id)
        || fixtureAdminRequestTypes.some((t) => t.category_id === data.id)
      ) return false
      fixtureAdminCategories = fixtureAdminCategories.filter((c) => c.id !== data.id)
      return true

    case 'admin:getCompanies':
      return fixtureAdminCompanies
    case 'admin:createCompany':
      if (!isValidBrandingUrl(data.icon) || !isValidBrandingUrl(data.background)) return false
      fixtureAdminCompanies = [
        ...fixtureAdminCompanies,
        {
          id: fixtureAdminCompanies.length + 10, enabled: 1, admin_calls_allowed: 1, admin_messages_allowed: 1, admin_requests_allowed: 1,
          category_id: data.categoryId, boss_grade: data.bossGrade, numbers: [{ id: 900, label: 'Main', number: data.mainNumber, is_main: 1 }],
          ...data,
        },
      ]
      return { id: 99 }
    case 'admin:updateCompany':
      if (!isValidBrandingUrl(data.icon) || !isValidBrandingUrl(data.background)) return false
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) =>
        c.id === data.id ? { ...c, ...data, category_id: data.categoryId, boss_grade: data.bossGrade, enabled: data.enabled ? 1 : 0 } : c,
      )
      return true
    case 'admin:deleteCompany':
      // Mirrors the server: soft-delete only (plan review round 4 §9), so
      // message/call history for this company isn't wiped along with it.
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) => (c.id === data.id ? { ...c, enabled: 0 } : c))
      return true
    case 'admin:setCompanyCeiling':
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) =>
        c.id === data.id
          ? { ...c, admin_calls_allowed: data.callsAllowed ? 1 : 0, admin_messages_allowed: data.messagesAllowed ? 1 : 0, admin_requests_allowed: data.requestsAllowed ? 1 : 0 }
          : c,
      )
      return true
    case 'admin:assignBoss':
      return true
    case 'admin:createNumber': {
      // Mirrors the server's UNIQUE KEY `number` check (plan review round 6
      // §2) - global across every company's numbers, not just this one.
      const clash = fixtureAdminCompanies.some((c) => c.numbers.some((n) => n.number === data.number))
      if (clash) return false

      fixtureAdminCompanies = fixtureAdminCompanies.map((c) =>
        c.id === data.companyId
          ? { ...c, numbers: [...c.numbers, { id: Date.now(), label: data.label, number: data.number, is_main: 0, enabled: 1 }] }
          : c,
      )
      return true
    }
    // Editing a number - including the main one (plan review round 6 §1).
    // Same uniqueness check as create, excluding this number's own row.
    case 'admin:updateNumber': {
      const clash = fixtureAdminCompanies.some((c) => c.numbers.some((n) => n.number === data.number && n.id !== data.id))
      if (clash) return false

      fixtureAdminCompanies = fixtureAdminCompanies.map((c) => ({
        ...c,
        numbers: c.numbers.map((n) => (n.id === data.id ? { ...n, label: data.label, number: data.number } : n)),
      }))
      return true
    }
    // Mirrors the server: soft-delete only (plan review round 5 §1), so
    // chat/call history for this number isn't wiped along with it.
    case 'admin:deleteNumber':
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) => ({
        ...c,
        numbers: c.numbers.map((n) => (n.id === data.id ? { ...n, enabled: 0 } : n)),
      }))
      return true
    case 'admin:enableNumber':
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) => ({
        ...c,
        numbers: c.numbers.map((n) => (n.id === data.id ? { ...n, enabled: 1 } : n)),
      }))
      return true

    case 'admin:getRequestTypes':
      return fixtureAdminRequestTypes
    case 'admin:createRequestType':
      fixtureAdminRequestTypes = [
        ...fixtureAdminRequestTypes,
        {
          id: fixtureAdminRequestTypes.length + 1, category_id: data.categoryId,
          passenger_count: data.passengerMode !== 'disabled' ? 1 : 0, passenger_mode: data.passengerMode,
          count_label: data.countLabel || 'Passenger count', icon: requestTypeIdentifier(data.name), note_mode: data.noteMode,
          description_enabled: data.noteMode !== 'disabled' ? 1 : 0, competition_enabled: data.competitionEnabled ? 1 : 0,
          enabled: 1, ...data,
        },
      ]
      return true
    case 'admin:updateRequestType':
      fixtureAdminRequestTypes = fixtureAdminRequestTypes.map((t) =>
        t.id === data.id
          ? {
              ...t, ...data, category_id: data.categoryId,
              passenger_count: data.passengerMode !== 'disabled' ? 1 : 0, passenger_mode: data.passengerMode,
              count_label: data.countLabel || 'Passenger count', icon: requestTypeIdentifier(data.name), note_mode: data.noteMode,
              description_enabled: data.noteMode !== 'disabled' ? 1 : 0, competition_enabled: data.competitionEnabled ? 1 : 0,
              enabled: data.enabled !== false ? 1 : 0,
            }
          : t,
      )
      return true
    case 'admin:deleteRequestType':
      // Mirrors the server: soft-delete only (plan review round 3 §9), so
      // request history for this type isn't wiped along with it.
      fixtureAdminRequestTypes = fixtureAdminRequestTypes.map((t) => (t.id === data.id ? { ...t, enabled: 0 } : t))
      return true

    default:
      return false
  }
}

/**
 * @param {string} action
 * @param {object} [data]
 * @returns {Promise<any>} the raw reply from the server, or `false` on failure
 */
export function fetchNui(action, data = {}) {
  if (devMode) return fetchNuiFixture(action, data)
  return window.fetchNui(action, data)
}

export function getSettings() {
  if (devMode || !window.getSettings) return Promise.resolve(null)
  return window.getSettings()
}

export function onSettingsChange(cb) {
  if (devMode || !window.onSettingsChange) return
  const unsubscribe = window.onSettingsChange(cb)
  return typeof unsubscribe === 'function' ? unsubscribe : undefined
}

/**
 * Live push from the server via client/main.lua's SendCustomAppMessage relay
 * (plan review §15) - e.g. a new message landing in an already-open
 * conversation, without waiting for the user to reopen it.
 * @param {string} event
 * @param {(data: any) => void} cb
 */
export function onNuiEvent(event, cb) {
  if (devMode || !window.onNuiEvent) return
  const unsubscribe = window.onNuiEvent(event, cb)
  return typeof unsubscribe === 'function' ? unsubscribe : undefined
}

/** @param {{ company?: string, number?: string, videoCall?: boolean, hideNumber?: boolean }} options */
export function createCall(options) {
  if (devMode || !window.createCall) {
    console.log('[dev] createCall', options)
    return
  }
  window.createCall(options)
}
