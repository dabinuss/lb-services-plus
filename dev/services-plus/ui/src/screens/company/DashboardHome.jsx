import { useEffect, useState } from 'react'
import { fetchNui, createCall } from '../../lib/nui.js'
import Switch from '../../components/Switch.jsx'

// Colored presence dots instead of plain typographic symbols (✓ ‖ ●) - a
// proper little status icon per option, not just a character.
const STATUSES = [
  { key: 'available', label: 'Available', icon: '🟢' },
  { key: 'pause', label: 'Pause', icon: '🟡' },
  { key: 'busy', label: 'Busy', icon: '🔴' },
]

// Duty, status and hotlines (plan §19-23).
export default function DashboardHome({ initialOnDuty, initialStatus, employeeName, employeeGrade, onLogout }) {
  const [onDuty, setOnDuty] = useState(initialOnDuty)
  const [status, setStatus] = useState(initialStatus)
  const [hotlines, setHotlines] = useState(null)
  const [notice, setNotice] = useState('')
  const [team, setTeam] = useState(null)
  const [teamSearch, setTeamSearch] = useState('')

  useEffect(() => {
    fetchNui('getHotlines').then((result) => result && setHotlines(result))
    fetchNui('getTeam').then((result) => result && setTeam(result))
  }, [])

  // Team moved here, right under Hotlines (plan review UX follow-up) - it
  // was its own tab, but with duty/status/hotlines/team/messages/calls/
  // settings all in one segmented control, the row no longer fit the phone
  // screen width and got clipped. Only ever shows on-duty colleagues
  // anyway, so pairing it with the other "who's around right now" info
  // here reads naturally, and a search bar keeps a larger team scannable.
  const visibleTeam = team?.filter((m) => m.name.toLowerCase().includes(teamSearch.trim().toLowerCase()))

  // Going off-duty ends the fake-login session, not just the duty flag -
  // "offline" is one of the only three things allowed to log the player
  // out (explicit logout, going off-duty, switching to a different phone
  // number).
  const toggleDuty = async (next) => {
    if (!(await fetchNui('toggleDuty', { onDuty: next }))) return

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
    if (await fetchNui('setStatus', { status: next })) {
      setStatus(next)
      setTeam((prev) => prev?.map((m) => (m.name === employeeName ? { ...m, status: next } : m)))
    }
  }

  const toggleHotline = async (line) => {
    const result = await fetchNui('toggleHotline', { numberId: line.numberId, active: !line.active })
    if (result?.ok) {
      setHotlines(result.hotlines)
      setNotice('')
      const activeLabels = result.hotlines.filter((h) => h.active).map((h) => h.label)
      setTeam((prev) => prev?.map((m) => (m.name === employeeName ? { ...m, hotlines: activeLabels } : m)))
    } else if (result?.reason === 'sole_employee') {
      setNotice("Main hotline stays on while you're the only one on duty.")
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
            <div className="dashboard-label">On duty</div>
            <div className="dashboard-row-sub">
              {employeeName}
              {employeeGrade && ` · ${employeeGrade}`}
            </div>
          </div>
          <Switch checked={onDuty} onChange={toggleDuty} small={false} />
        </div>

        {onDuty && (
          <div className="duty-card-actions">
            {STATUSES.map((s) => (
              <button
                key={s.key}
                className={`status-pill ${s.key}${status === s.key ? ' active' : ''}`}
                onClick={() => changeStatus(s.key)}
              >
                <span className="status-pill-icon">{s.icon}</span>
                {s.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {onDuty && (
        <>
          <div className="section-title">Hotlines</div>
          <div className="hotline-list">
            {hotlines === null && <div className="empty-state">Loading…</div>}
            {hotlines?.map((line) => (
              <div key={line.numberId} className="hotline-row">
                <span>
                  {line.label}
                  {line.locked && <span className="hint"> (locked)</span>}
                </span>
                <Switch checked={line.active} disabled={line.locked} onChange={() => toggleHotline(line)} />
              </div>
            ))}
          </div>
          {notice && <div className="notice">{notice}</div>}

          <div className="section-title">Team</div>
          <input
            className="search-input"
            placeholder="Search team…"
            value={teamSearch}
            onChange={(e) => setTeamSearch(e.target.value)}
          />
          <div className="team-list">
            {team === null && <div className="empty-state">Loading…</div>}
            {team !== null && visibleTeam.length === 0 && <div className="empty-state">Nobody on duty.</div>}
            {visibleTeam?.map((member, i) => (
              <div key={i} className="team-row">
                <div className="team-row-main">
                  <div className="team-info">
                    <div className="team-name">{member.name}</div>
                    <div className="team-grade">{member.gradeLabel}</div>
                  </div>
                  <div className="team-meta">
                    <span className={`status-pill ${member.status} static`}>{member.status}</span>
                    <div className="team-hotlines">{member.hotlines.join(', ') || '—'}</div>
                  </div>
                </div>
                {member.phoneNumber && (
                  <button className="icon-button call" onClick={() => createCall({ number: member.phoneNumber })} aria-label="Call">
                    📞
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
