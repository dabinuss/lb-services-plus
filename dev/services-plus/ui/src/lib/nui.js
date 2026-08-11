// Thin wrapper around the globals lb-phone injects into a custom app's
// iframe (see docs.lbscripts.com/phone/custom-apps and client/main.lua on
// the Lua side). Falls back to small in-memory fixtures when running via
// `npm run dev` in a plain browser tab, so the UI is iterable without a
// running FiveM server.

export const devMode = !window.invokeNative

const fixtures = {
  bootstrap: {
    categories: [
      { id: 1, key: 'police', name: 'Police', icon: 'police', sort_order: 10 },
      { id: 2, key: 'medical', name: 'Medical', icon: 'medical', sort_order: 20 },
      { id: 3, key: 'taxi', name: 'Taxi', icon: 'taxi', sort_order: 30 },
      { id: 4, key: 'mechanic', name: 'Mechanic', icon: 'wrench', sort_order: 40 },
    ],
    companies: [
      {
        id: 1,
        job: 'police',
        name: 'Los Santos Police Department',
        categoryId: 1,
        icon: 'https://cdn-icons-png.flaticon.com/512/7211/7211100.png',
        background: null,
        available: true,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [{ id: 1, label: 'Main Hotline', isMain: true, callsEnabled: true, messagesEnabled: true }],
      },
      {
        id: 2,
        job: 'ambulance',
        name: 'Pillbox Medical',
        categoryId: 2,
        icon: 'https://cdn-icons-png.flaticon.com/128/1032/1032989.png',
        background: null,
        available: false,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [{ id: 2, label: 'Main Hotline', isMain: true, callsEnabled: true, messagesEnabled: true }],
      },
      {
        id: 3,
        job: 'mechanic',
        name: 'Downtown Cab Co.',
        categoryId: 4,
        icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png',
        background: null,
        available: true,
        callsEnabled: true,
        messagesEnabled: true,
        requestsEnabled: true,
        numbers: [
          { id: 3, label: 'Main Hotline', isMain: true, callsEnabled: true, messagesEnabled: true },
          { id: 4, label: 'Workshop', isMain: false, callsEnabled: true, messagesEnabled: true },
        ],
      },
    ],
    myNumber: '5550100',
    admin: true,
    employee: {
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
  requestTypes: {
    4: [
      {
        id: 1, category_id: 4, name: 'Roadside Assistance', icon: 'wrench',
        description: 'Request on-site repairs.', passenger_count: 0, description_enabled: 1,
      },
    ],
    3: [
      {
        id: 2, category_id: 3, name: 'Taxi Pickup', icon: 'taxi',
        description: 'Request a ride from your current location.', passenger_count: 1, description_enabled: 1,
      },
    ],
  },
}

let fixtureMessages = [
  { id: 1, sender: '5550100', content: 'Hey, is anyone there?', created_at: new Date(Date.now() - 60000).toISOString() },
]

let fixtureActivity = [
  {
    channel_id: 1,
    last_message: 'Hey, is anyone there?',
    updated_at: new Date().toISOString(),
    company: { id: 3, name: 'Downtown Cab Co.', icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png' },
  },
]

let fixtureRequests = [
  {
    id: 1, status: 'open', request_type_id: 2, company_id: null, passenger_count: 2, description: 'Alta Street',
    type_name: 'Taxi Pickup', type_icon: 'taxi', is_mine: false, pos_x: 100, pos_y: 200,
    created_at: new Date(Date.now() - 30000).toISOString(),
  },
]

const fixtureCalls = [
  {
    id: 1, customer_number: '5559876', employee_number: null, state: 'missed', label: 'Main Hotline',
    company_name: 'Downtown Cab Co.', company_icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png',
    created_at: new Date(Date.now() - 3600000).toISOString(),
  },
]

let fixtureHotlines = [
  { numberId: 3, label: 'Main Hotline', active: true, locked: false },
  { numberId: 4, label: 'Workshop', active: false, locked: false },
]

const fixtureTeam = [
  { name: 'Dabi', gradeLabel: 'Boss', status: 'available', hotlines: ['Main Hotline'] },
  { name: 'John', gradeLabel: 'Worker', status: 'busy', hotlines: ['Main Hotline', 'Workshop'] },
]

let fixtureSettings = {
  callsEnabled: true, messagesEnabled: true, requestsEnabled: true,
  adminCallsAllowed: true, adminMessagesAllowed: true, adminRequestsAllowed: true,
  callRouting: 'all', requestRouting: 'all',
  numbers: [
    { id: 3, label: 'Main Hotline', isMain: true, callsEnabled: true, messagesEnabled: true, mailboxEnabled: true },
    { id: 4, label: 'Workshop', isMain: false, callsEnabled: true, messagesEnabled: true, mailboxEnabled: true },
  ],
}

// --------------------------------------------------------- admin fixtures

let fixtureAdminCategories = [
  { id: 1, key: 'police', name: 'Police', icon: 'police', sort_order: 10, competition_allowed: 0 },
  { id: 2, key: 'medical', name: 'Medical', icon: 'medical', sort_order: 20, competition_allowed: 0 },
  { id: 3, key: 'taxi', name: 'Taxi', icon: 'taxi', sort_order: 30, competition_allowed: 1 },
  { id: 4, key: 'mechanic', name: 'Mechanic', icon: 'wrench', sort_order: 40, competition_allowed: 1 },
]

let fixtureAdminCompanies = [
  {
    id: 3, job: 'mechanic', name: 'Downtown Cab Co.', category_id: 4, boss_grade: 4, enabled: 1,
    admin_calls_allowed: 1, admin_messages_allowed: 1, admin_requests_allowed: 1,
    icon: 'https://cdn-icons-png.flaticon.com/128/10281/10281554.png', background: null,
    numbers: [
      { id: 3, label: 'Main Hotline', number: '911', is_main: 1 },
      { id: 4, label: 'Workshop', number: '5550199', is_main: 0 },
    ],
  },
]

let fixtureAdminRequestTypes = [
  {
    id: 2, category_id: 3, name: 'Taxi Pickup', icon: 'taxi', description: 'Request a ride.',
    passenger_count: 1, description_enabled: 1, competition_enabled: 1,
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
        employee: { name: 'Dabi', grade: 4, gradeLabel: 'Boss', isBoss: true, onDuty: true },
      }
    case 'toggleDuty':
    case 'setStatus':
      return true
    case 'openConversation':
    case 'getMessages':
      return { channelId: 1, contactNumber: '5550100', messages: [...fixtureMessages].reverse() }
    case 'sendMessage': {
      const message = { id: fixtureMessages.length + 1, sender: fixtures.bootstrap.myNumber, content: data.content }
      fixtureMessages.push(message)
      return message
    }
    case 'getActivity':
      return fixtureActivity
    case 'archiveConversation':
      return true
    case 'resolveCall':
      return data.numberId === 3 ? { company: 'mechanic' } : { number: '5551234' }
    case 'getCallHistory':
    case 'getMyCalls':
      return fixtureCalls
    case 'getHotlines':
      return fixtureHotlines
    case 'toggleHotline':
      fixtureHotlines = fixtureHotlines.map((h) => (h.numberId === data.numberId ? { ...h, active: data.active } : h))
      return { ok: true, hotlines: fixtureHotlines }
    case 'getTeam':
      return fixtureTeam
    case 'getCompanyConversations':
      return [{ channel_id: 1, contact_number: '5550100', last_message: 'Hey, is anyone there?', label: 'Main Hotline' }]
    case 'getCompanySettings':
      return fixtureSettings
    case 'updateCompanySettings':
      fixtureSettings = { ...fixtureSettings, ...data.settings }
      return true
    case 'updateNumberSettings':
      fixtureSettings = {
        ...fixtureSettings,
        numbers: fixtureSettings.numbers.map((n) => (n.id === data.numberId ? { ...n, ...data.settings } : n)),
      }
      return true
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
      return fixtureRequests
    case 'getMyRequests':
      return fixtureRequests.map((r) => ({ ...r, company_name: 'Downtown Cab Co.', company_icon: fixtures.bootstrap.companies[2].icon }))
    case 'setWaypoint':
      console.log('[dev] setWaypoint', data)
      return true

    // -- admin --------------------------------------------------------
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
      fixtureAdminCategories = fixtureAdminCategories.filter((c) => c.id !== data.id)
      return true

    case 'admin:getCompanies':
      return fixtureAdminCompanies
    case 'admin:createCompany':
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
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) =>
        c.id === data.id ? { ...c, ...data, category_id: data.categoryId, boss_grade: data.bossGrade, enabled: data.enabled ? 1 : 0 } : c,
      )
      return true
    case 'admin:deleteCompany':
      fixtureAdminCompanies = fixtureAdminCompanies.filter((c) => c.id !== data.id)
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
    case 'admin:createNumber':
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) =>
        c.id === data.companyId
          ? { ...c, numbers: [...c.numbers, { id: Date.now(), label: data.label, number: data.number, is_main: 0 }] }
          : c,
      )
      return true
    case 'admin:deleteNumber':
      fixtureAdminCompanies = fixtureAdminCompanies.map((c) => ({ ...c, numbers: c.numbers.filter((n) => n.id !== data.id) }))
      return true

    case 'admin:getRequestTypes':
      return fixtureAdminRequestTypes
    case 'admin:createRequestType':
      fixtureAdminRequestTypes = [
        ...fixtureAdminRequestTypes,
        {
          id: fixtureAdminRequestTypes.length + 1, category_id: data.categoryId, passenger_count: data.passengerCount ? 1 : 0,
          description_enabled: data.descriptionEnabled ? 1 : 0, competition_enabled: data.competitionEnabled ? 1 : 0, ...data,
        },
      ]
      return true
    case 'admin:updateRequestType':
      fixtureAdminRequestTypes = fixtureAdminRequestTypes.map((t) =>
        t.id === data.id
          ? { ...t, ...data, category_id: data.categoryId, passenger_count: data.passengerCount ? 1 : 0, description_enabled: data.descriptionEnabled ? 1 : 0, competition_enabled: data.competitionEnabled ? 1 : 0 }
          : t,
      )
      return true
    case 'admin:deleteRequestType':
      fixtureAdminRequestTypes = fixtureAdminRequestTypes.filter((t) => t.id !== data.id)
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
  window.onSettingsChange(cb)
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
  window.onNuiEvent(event, cb)
}

/** @param {{ company?: string, number?: string, videoCall?: boolean, hideNumber?: boolean }} options */
export function createCall(options) {
  if (devMode || !window.createCall) {
    console.log('[dev] createCall', options)
    return
  }
  window.createCall(options)
}
