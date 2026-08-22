import { useEffect, useRef, useState } from 'react'
import { fetchNui, createCall } from '../../lib/nui.js'
import Switch from '../../components/Switch.jsx'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'

// A colored presence dot per option (same shared Icon set as the rest of
// the app, colored via CSS below) plus its own label - never just a color
// on its own, so the status still reads for anyone who can't tell the
// colors apart.
const STATUSES = [
  { key: 'available', label: 'Available' },
  { key: 'pause', label: 'Pause' },
  { key: 'busy', label: 'Busy' },
]

// Duty, status and hotlines (plan §19-23).
export default function DashboardHome({ initialOnDuty, initialStatus, employeeMemberId, employeeName, employeeGrade, onLogout, teamUpdate }) {
  const { t } = useI18n()
  const [onDuty, setOnDuty] = useState(initialOnDuty)
  const [status, setStatus] = useState(initialStatus)
  const [hotlines, setHotlines] = useState(null)
  const [notice, setNotice] = useState('')
  const [team, setTeam] = useState(null)
  const [teamSearch, setTeamSearch] = useState('')
  const [statusSaving, setStatusSaving] = useState(false)
  const statusLock = useRef(false)
  const [dutySaving, setDutySaving] = useState(false)
  const dutyLock = useRef(false)
  const [hotlineSaving, setHotlineSaving] = useState(null)
  const hotlineLock = useRef(false)

  useEffect(() => {
    fetchNui('getHotlines').then((result) => result && setHotlines(result))
    fetchNui('getTeam').then((result) => result && setTeam(result))
  }, [])

  // A colleague's own status/hotline/duty change, pushed in real time
  // instead of only ever reflecting what getTeam() returned at mount (plan
  // review round 5 §8, round 6 §4). `removed: true` (going off duty, or
  // changing to a different job entirely) drops the row instead of
  // upserting it - the one transition that doesn't produce a normal row
  // from the server (GetTeamMemberRow returns nil for "not on duty").
  //
  // Player source is a stable identity for this online/session-only list.
  // It remains available to playerDropped even when phone/name lookups no
  // longer do, and duplicate names can never affect another row.
  useEffect(() => {
    if (!teamUpdate) return
    const matches = (m) => m.memberId === teamUpdate.memberId
    setTeam((prev) => {
      if (!prev) return prev
      if (teamUpdate.removed) return prev.filter((m) => !matches(m))
      return prev.some(matches) ? prev.map((m) => (matches(m) ? teamUpdate : m)) : [...prev, teamUpdate]
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [teamUpdate])

  // Team moved here, right under Hotlines (plan review UX follow-up) - it
  // was its own tab, but with duty/status/hotlines/team/messages/calls/
  // settings all in one segmented control, the row no longer fit the phone
  // screen width and got clipped. Only ever shows on-duty colleagues
  // anyway, so pairing it with the other "who's around right now" info
  // here reads naturally, and a search bar keeps a larger team scannable.
  const visibleTeam = team?.filter((m) => {
    const search = teamSearch.trim().toLowerCase()
    return m.name.toLowerCase().includes(search) || m.gradeLabel?.toLowerCase().includes(search)
  })

  // Going off-duty ends the fake-login session, not just the duty flag -
  // "offline" is one of the only three things allowed to log the player
  // out (explicit logout, going off-duty, switching to a different phone
  // number).
  const toggleDuty = async (next) => {
    if (dutyLock.current) return
    dutyLock.current = true
    setDutySaving(true)
    let result = false
    try {
      result = await fetchNui('toggleDuty', { onDuty: next })
    } finally {
      dutyLock.current = false
      setDutySaving(false)
    }
    if (!result) return

    if (next) {
      setOnDuty(true)
      // The mount-time getTeam() fetch may predate this player actually
      // being on duty (logged in while off, then flipped on) - refetch so
      // their own row (and anyone else who joined meanwhile) is accurate
      // instead of stale from before they existed in it.
      fetchNui('getTeam').then((result) => result && setTeam(result))
    } else {
      onLogout()
    }
  }

  // Own status/hotline changes only ever patched `status`/`hotlines` state,
  // never the already-loaded `team` list's own row for this player - it
  // could show "available" underneath while "Busy" was selected right
  // above (plan review round 4 §8). No polling/new event system for
  // colleagues' changes per review guidance - just keep this player's own
  // row in sync locally, the same data already in hand either way.
  const changeStatus = async (next) => {
    if (statusLock.current || next === status) return
    statusLock.current = true
    setStatusSaving(true)
    try {
      if (await fetchNui('setStatus', { status: next })) {
        setStatus(next)
        setTeam((prev) => prev?.map((m) => (m.memberId === employeeMemberId ? { ...m, status: next } : m)))
      }
    } finally {
      statusLock.current = false
      setStatusSaving(false)
    }
  }

  const toggleHotline = async (line) => {
    if (hotlineLock.current) return
    hotlineLock.current = true
    setHotlineSaving(line.numberId)
    try {
      const result = await fetchNui('toggleHotline', { numberId: line.numberId, active: !line.active })
      if (result?.ok) {
        setHotlines(result.hotlines)
        setNotice('')
        const activeLabels = result.hotlines.filter((h) => h.active).map((h) => h.label)
        setTeam((prev) => prev?.map((m) => (m.memberId === employeeMemberId ? { ...m, hotlines: activeLabels } : m)))
      } else if (result?.reason === 'sole_employee') {
        setNotice(t("Main hotline stays on while you're the only one on duty."))
      }
    } finally {
      hotlineLock.current = false
      setHotlineSaving(null)
    }
  }

  return (
    <div className="tab-panel">
      {/* One grouped card, banner-and-actions-row style like the company
          cards on the Services overview - "On duty" used to sit in its own
          floating row with the status pills as a disconnected block below
          it; now the toggle is the "banner" and the three status buttons
          are the actions row underneath, same visual family. */}
      <div className="duty-card">
        <div className="duty-card-top">
          <div>
            <div className="dashboard-label">{t('On duty')}</div>
            <div className="dashboard-row-sub">
              {employeeName}
              {employeeGrade && ` · ${employeeGrade}`}
            </div>
          </div>
          <Switch checked={onDuty} onChange={toggleDuty} disabled={dutySaving} small={false} />
        </div>

        {onDuty && (
          <div className="duty-card-actions">
            {STATUSES.map((s) => (
              <button
                key={s.key}
                className={`status-pill ${s.key}${status === s.key ? ' active' : ''}`}
                onClick={() => changeStatus(s.key)}
                disabled={statusSaving}
                aria-busy={statusSaving && status !== s.key}
              >
                <Icon name="dot" size={10} className={`status-pill-icon ${s.key}`} />
                {t(s.label)}
              </button>
            ))}
          </div>
        )}
      </div>

      {onDuty && (
        <>
          <div className="section-title">{t('Hotlines')}</div>
          <div className="hotline-list">
            {hotlines === null && <div className="empty-state">{t('Loading hotlines…')}</div>}
            {hotlines?.map((line) => (
              <div key={line.numberId} className="hotline-row">
                <div className="hotline-info">
                  <span className="hotline-label">
                    {line.label}
                    {line.locked && <span className="hint"> ({t('locked')})</span>}
                  </span>
                  <span className="hotline-number">{line.number}</span>
                </div>
                <Switch checked={line.active} disabled={line.locked || hotlineSaving !== null} onChange={() => toggleHotline(line)} />
              </div>
            ))}
          </div>
          {notice && <div className="notice">{notice}</div>}

          <div className="section-title">{t('Team')}</div>
          <input
            className="search-input"
            placeholder={t('Search team…')}
            value={teamSearch}
            onChange={(e) => setTeamSearch(e.target.value)}
          />
          <div className="team-list">
            {team === null && <div className="empty-state">{t('Loading team…')}</div>}
            {team !== null && visibleTeam.length === 0 && (
              <div className="empty-state">
                {t(teamSearch.trim() ? 'No colleague matches that search.' : 'No colleagues on duty right now.')}
              </div>
            )}
            {visibleTeam?.map((member) => (
              <div key={member.memberId} className="team-row">
                <div className="team-row-main">
                  <div className="team-info">
                    <div className="team-name">{member.name}</div>
                    <div className="team-grade">{member.gradeLabel}</div>
                  </div>
                  <div className="team-meta">
                    <span className={`status-pill ${member.status} static`}>{t(member.status)}</span>
                    <div className="team-hotlines">{member.hotlines.join(', ') || '—'}</div>
                  </div>
                </div>
                {member.phoneNumber && (
                  <button className="icon-button call" onClick={() => createCall({ number: member.phoneNumber })} aria-label={t('Call')}>
                    <Icon name="phone" size={15} />
                  </button>
                )}
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
