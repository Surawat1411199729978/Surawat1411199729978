import { render } from 'preact'
import { useEffect, useState } from 'preact/hooks'
import {
  ACTIONS, BRAND_KINDS, MATERIALS, PALETTE, PRIORITIES, STATUSES,
  addDays, addMonths, fmtDayMonth, fmtFull, fmtMonthYear, fmtRelative, fromInputDate, isOverdue, isThisWeek,
  material, newTask, nextStatus, paletteColor, priority, sameDay, sameMonth, startOfDay, startOfMonth,
  startOfWeek, status, toInputDate, uuid, webURL, weekGroups,
} from './model.js'
import {
  consumeInviteLink, parseFirebaseConfig, store, todoStore, useStore, useTodos,
} from './store.js'

const invitedTeamCode = consumeInviteLink()

const read = (key, fallback = '') => {
  try {
    return localStorage.getItem(key) ?? fallback
  } catch {
    return fallback
  }
}
const write = (key, value) => {
  try {
    localStorage.setItem(key, value)
  } catch {}
}

function useUserName() {
  const [name, setName] = useState(read('userName'))
  return [name, (v) => { setName(v); write('userName', v) }]
}

// ---------- Small pieces ----------

function Avatar({ name, colorIndex, size = 28 }) {
  const color = paletteColor(colorIndex ?? 0)
  return (
    <span class="avatar" style={{ width: size, height: size, fontSize: size * 0.42, color, background: `${color}26` }}>
      {(name || '?').charAt(0).toUpperCase()}
    </span>
  )
}

function StatusPill({ id }) {
  const s = status(id)
  return <span class="pill" style={{ color: s.color, background: `${s.color}1f` }}>{s.title}</span>
}

function StatGrid({ tasks, selected, onSelect }) {
  return (
    <div class="grid2">
      {STATUSES.map((s) => (
        <button
          key={s.id}
          class={`stat ${selected === s.id ? 'selected' : ''}`}
          style={{ color: s.color }}
          onClick={onSelect ? () => onSelect(selected === s.id ? null : s.id) : undefined}
        >
          <div class="stat-head" style={{ background: `${s.color}24` }}>{s.title}</div>
          <div class="stat-num">{tasks.filter((t) => t.status === s.id).length}</div>
        </button>
      ))}
    </div>
  )
}

function TopBar({ title, left, right, small }) {
  return (
    <div class="topbar">
      {left ?? (small ? <span style={{ minWidth: 44 }} /> : null)}
      {small ? <div class="title-sm">{title}</div> : <h1>{title}</h1>}
      {right ?? (small ? <span style={{ minWidth: 44 }} /> : null)}
    </div>
  )
}

function Empty({ icon, text }) {
  return (
    <div class="empty">
      <div class="big">{icon}</div>
      <div>{text}</div>
    </div>
  )
}

function TaskRow({ task, onOpen, showNext = true }) {
  const member = store.member(task.assigneeID)
  const brand = store.brand(task.brandID)
  const next = nextStatus(task.status)
  const done = task.checklist.filter((c) => c.isDone).length
  return (
    <div class="row" onClick={() => onOpen(task.id)} role="button">
      <div class="grow">
        <div style={{ display: 'flex', gap: 8, alignItems: 'baseline' }}>
          <span class="task-title grow">{task.title}</span>
          <StatusPill id={task.status} />
        </div>
        <div class="task-meta">
          {member ? <Avatar name={member.name} colorIndex={member.colorIndex} size={20} /> : '👤'}
          <span>{member?.name ?? 'ยังไม่มอบหมาย'}</span>
          <span>·</span>
          <span class="ellipsis">{material(task.material).title}</span>
        </div>
        <div class="task-sub">
          <span class={isOverdue(task) ? 'danger' : ''}>📅 {fmtDayMonth(task.dueDate)}</span>
          {brand && (
            <span class="ellipsis" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <i class="dot" style={{ background: paletteColor(brand.colorIndex) }} />
              {brand.name}
            </span>
          )}
          <span class="grow" />
          {task.checklist.length > 0 && <span>☑︎ {done}/{task.checklist.length}</span>}
          {task.comments.length > 0 && <span>💬 {task.comments.length}</span>}
        </div>
      </div>
      {showNext && next && (
        <button
          class="next-btn"
          style={{ color: next.color, background: `${next.color}1f` }}
          title={`ย้ายไป ${next.title}`}
          onClick={(e) => {
            e.stopPropagation()
            store.setStatus(task, next.id)
          }}
        >
          → {next.title}
        </button>
      )}
    </div>
  )
}

function Field({ label, children }) {
  return (
    <label class="row input-row">
      <span>{label}</span>
      {children}
    </label>
  )
}

function ColorPicker({ value, onChange }) {
  return (
    <div class="colors">
      {PALETTE.map((c, i) => (
        <button key={c} type="button" class={value === i ? 'on' : ''} style={{ background: c }} onClick={() => onChange(i)}>
          {value === i ? '✓' : ''}
        </button>
      ))}
    </div>
  )
}

// ---------- Setup screens ----------

function ConfigSetup() {
  const [text, setText] = useState('')
  const [error, setError] = useState('')
  const submit = () => {
    const config = parseFirebaseConfig(text)
    if (!config) {
      setError('อ่านค่าไม่ได้ ตรวจว่าวางข้อความที่มี apiKey, projectId และ appId ครบ')
      return
    }
    store.saveConfig(config)
    store.start()
  }
  return (
    <div class="screen no-tabbar">
      <TopBar title="ตั้งค่า Firebase" />
      <div class="card">
        <p style={{ marginTop: 0 }}>
          ทำแค่ครั้งเดียว โดยคนที่สร้างทีม เพื่อน ๆ ในทีมจะได้ลิงก์เชิญที่ตั้งค่าให้อัตโนมัติ ไม่ต้องทำขั้นนี้
        </p>
        <ol class="steps small">
          <li>เข้า <a href="https://console.firebase.google.com" target="_blank" rel="noreferrer">console.firebase.google.com</a> แล้วสร้างโปรเจกต์ (หรือใช้โปรเจกต์เดิมของแอพ iOS)</li>
          <li>Authentication → Sign-in method → เปิด <b>Anonymous</b></li>
          <li>Firestore Database → Create database แล้ววางกฎจากไฟล์ <code>firestore.rules</code> ในแท็บ Rules</li>
          <li>Project settings (⚙️) → Your apps → กดไอคอน <b>&lt;/&gt;</b> (Web) → ตั้งชื่อ แล้วคัดลอกข้อความ <code>const firebaseConfig = {'{...}'}</code></li>
          <li>วางข้อความนั้นในช่องด้านล่าง</li>
        </ol>
      </div>
      <textarea
        class="config"
        placeholder={'const firebaseConfig = {\n  apiKey: "...",\n  authDomain: "...",\n  projectId: "...",\n  appId: "..."\n};'}
        value={text}
        onInput={(e) => setText(e.currentTarget.value)}
      />
      {error && <p class="danger small">{error}</p>}
      <button class="btn" disabled={!text.trim()} onClick={submit}>บันทึกและเชื่อมต่อ</button>
    </div>
  )
}

function TeamSetup() {
  const [userName, setUserName] = useUserName()
  const [mode, setMode] = useState(invitedTeamCode ? 'join' : 'join')
  const [code, setCode] = useState(invitedTeamCode ?? '')
  const [teamName, setTeamName] = useState('Digital Marketing Team')
  const [withSample, setWithSample] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const name = userName.trim()
  const canSubmit = name && !busy && (mode === 'join' ? code.trim() : teamName.trim())

  const submit = async () => {
    setBusy(true)
    setError('')
    try {
      if (mode === 'join') await store.joinTeam({ code, yourName: name })
      else await store.createTeam({ name: teamName.trim(), yourName: name, withSampleData: withSample })
      setUserName(name)
    } catch (e) {
      setError(e?.message ?? String(e))
    }
    setBusy(false)
  }

  return (
    <div class="screen no-tabbar">
      <div class="empty" style={{ paddingBottom: 8 }}>
        <div class="big">👥</div>
        <h2 style={{ margin: '8px 0 4px' }}>ติดตามงานร่วมกับทีม</h2>
        <div class="small">ทุกคนในทีมจะเห็นงานชุดเดียวกันแบบ real-time</div>
      </div>

      <div class="section-title plain">ชื่อของคุณ</div>
      <div class="list">
        <label class="row input-row">
          <input placeholder="เช่น Hannah" value={userName} onInput={(e) => setUserName(e.currentTarget.value)} />
        </label>
      </div>

      <div class="segmented">
        <button class={mode === 'join' ? 'on' : ''} onClick={() => setMode('join')}>เข้าร่วมทีม</button>
        <button class={mode === 'create' ? 'on' : ''} onClick={() => setMode('create')}>สร้างทีมใหม่</button>
      </div>

      {mode === 'join' ? (
        <>
          <div class="list">
            <label class="row input-row">
              <input
                class="code"
                style={{ fontSize: 20 }}
                placeholder="รหัสทีม 8 ตัวอักษร"
                autocapitalize="characters"
                autocomplete="off"
                value={code}
                onInput={(e) => setCode(e.currentTarget.value.toUpperCase())}
              />
            </label>
          </div>
          <p class="small muted">ขอรหัสหรือลิงก์เชิญจากคนที่สร้างทีม (อยู่ในแท็บตั้งค่าของเขา)</p>
        </>
      ) : (
        <>
          <div class="list">
            <Field label="ชื่อทีม">
              <input style={{ textAlign: 'right' }} value={teamName} onInput={(e) => setTeamName(e.currentTarget.value)} />
            </Field>
            <Field label="เริ่มด้วยข้อมูลตัวอย่าง">
              <span class="grow" />
              <input type="checkbox" style={{ flex: 'none', width: 22, height: 22 }} checked={withSample}
                onChange={(e) => setWithSample(e.currentTarget.checked)} />
            </Field>
          </div>
          <p class="small muted">หลังสร้างทีม จะได้รหัสทีมและลิงก์เชิญไว้แชร์ให้เพื่อนร่วมทีม</p>
        </>
      )}

      {error && <p class="danger">⚠️ {error}</p>}
      <button class="btn" disabled={!canSubmit} onClick={submit}>
        {busy ? 'กำลังดำเนินการ...' : mode === 'join' ? 'เข้าร่วมทีม' : 'สร้างทีมใหม่'}
      </button>
    </div>
  )
}

// ---------- Dashboard ----------

function Dashboard({ state, openTask, newTaskAt }) {
  const todos = useTodos()
  const [userName] = useUserName()
  const now = new Date()
  const monthTasks = state.tasks.filter((t) => sameMonth(t.dueDate, now))
  const weekTasks = state.tasks.filter((t) => isThisWeek(t.dueDate))
  const endOfToday = addDays(startOfDay(now), 1)
  const attention = state.tasks.filter((t) => t.status !== 'posted' && t.dueDate < endOfToday)
  const posted = weekTasks.filter((t) => t.status === 'posted').length
  const progress = weekTasks.length ? posted / weekTasks.length : 0
  const todosDone = todos.filter((t) => t.isDone).length
  const maxCount = Math.max(1, ...state.members.map((m) => monthTasks.filter((t) => t.assigneeID === m.id).length))

  return (
    <div class="screen">
      <TopBar small title="ภาพรวม" right={<button class="icon-btn big" onClick={() => newTaskAt(now)}>＋</button>} />
      <div class="eyebrow">{state.teamName}</div>
      <h1 style={{ margin: '4px 0', fontSize: 30 }}>ยินดีต้อนรับกลับ, {userName || 'คุณ'}!</h1>
      <div class="muted">นี่คือสถานะงานของทีมในเดือนนี้</div>

      <StatGrid tasks={monthTasks} />

      <div class="card">
        <h3>⚠️ ต้องทำวันนี้ / เลยกำหนด</h3>
        {attention.length === 0 ? (
          <div class="muted">🎉 ไม่มีงานค้าง เยี่ยมมาก!</div>
        ) : (
          <div class="list" style={{ margin: '0 -16px -16px' }}>
            {attention.slice(0, 5).map((t) => <TaskRow key={t.id} task={t} onOpen={openTask} showNext={false} />)}
          </div>
        )}
      </div>

      <div class="kpi">
        <h3>KPI สัปดาห์นี้</h3>
        <div>โพสต์แล้ว {posted} จาก {weekTasks.length} งาน</div>
        <div class="progress"><div style={{ width: `${progress * 100}%` }} /></div>
        <div class="small" style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 600 }}>
          <span>📈 {Math.round(progress * 100)}%</span>
          <span>To-Do เสร็จ {todosDone}/{todos.length}</span>
        </div>
      </div>

      <div class="card">
        <h3>📊 งานของแต่ละคน (เดือนนี้)</h3>
        {state.members.length === 0 ? (
          <div class="muted">ยังไม่มีสมาชิก</div>
        ) : (
          <div class="bars">
            {state.members.map((m) => {
              const mine = monthTasks.filter((t) => t.assigneeID === m.id)
              return (
                <div class="bar-row" key={m.id}>
                  <span class="bar-name">{m.name}</span>
                  <div class="bar" style={{ background: 'none' }}>
                    {STATUSES.map((s) => {
                      const n = mine.filter((t) => t.status === s.id).length
                      return n ? <div key={s.id} style={{ width: `${(n / maxCount) * 100}%`, background: s.color }} /> : null
                    })}
                  </div>
                  <span class="muted small">{mine.length}</span>
                </div>
              )
            })}
            <div class="legend">
              {STATUSES.map((s) => <span key={s.id}><i class="dot" style={{ background: s.color }} />{s.title}</span>)}
            </div>
          </div>
        )}
      </div>

      <div class="card">
        <h3>👥 ทีม</h3>
        <div class="list" style={{ margin: '0 -16px -16px' }}>
          {state.members.map((m) => {
            const active = state.tasks.filter((t) => t.assigneeID === m.id && t.status !== 'posted').length
            return (
              <div class="row" key={m.id}>
                <Avatar name={m.name} colorIndex={m.colorIndex} size={34} />
                <div class="grow">
                  <div style={{ fontWeight: 600 }}>{m.name}</div>
                  {m.role && <div class="small muted">{m.role}</div>}
                </div>
                <span class="small" style={{ color: active ? 'var(--accent)' : 'var(--muted)' }}>{active} งานค้าง</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}

// ---------- Tasks ----------

function TasksScreen({ state, openTask, newTaskAt }) {
  const [month, setMonth] = useState(startOfMonth(new Date()))
  const [memberF, setMemberF] = useState('')
  const [brandF, setBrandF] = useState('')
  const [materialF, setMaterialF] = useState('')
  const [statusF, setStatusF] = useState(null)
  const [search, setSearch] = useState('')

  const monthTasks = state.tasks.filter((t) =>
    sameMonth(t.dueDate, month)
    && (!memberF || t.assigneeID === memberF)
    && (!brandF || t.brandID === brandF)
    && (!materialF || t.material === materialF)
    && (!search || t.title.toLowerCase().includes(search.toLowerCase())))
  const visible = statusF ? monthTasks.filter((t) => t.status === statusF) : monthTasks
  const weeks = weekGroups(visible, month)
  const hasFilters = memberF || brandF || materialF || statusF

  return (
    <div class="screen">
      <TopBar
        title="งานของทีม"
        right={<button class="icon-btn big" onClick={() => newTaskAt(sameMonth(month, new Date()) ? new Date() : month)}>＋</button>}
      />
      <input class="search" type="search" placeholder="🔍 ค้นหาชื่องาน" value={search} onInput={(e) => setSearch(e.currentTarget.value)} />

      <StatGrid tasks={monthTasks} selected={statusF} onSelect={setStatusF} />

      <div class="chips">
        <div class="chip month-chip">
          <button onClick={() => setMonth(addMonths(month, -1))}>‹</button>
          <span>{fmtMonthYear(month)}</span>
          <button onClick={() => setMonth(addMonths(month, 1))}>›</button>
        </div>
        <select class={`chip ${memberF ? 'active' : ''}`} value={memberF} onChange={(e) => setMemberF(e.currentTarget.value)}>
          <option value="">ทั้งทีม ▾</option>
          {state.members.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
        </select>
        <select class={`chip ${brandF ? 'active' : ''}`} value={brandF} onChange={(e) => setBrandF(e.currentTarget.value)}>
          <option value="">แบรนด์: ทั้งหมด ▾</option>
          {BRAND_KINDS.map((k) => (
            <optgroup key={k.id} label={k.title}>
              {state.brands.filter((b) => b.kind === k.id).map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
            </optgroup>
          ))}
        </select>
        <select class={`chip ${materialF ? 'active' : ''}`} value={materialF} onChange={(e) => setMaterialF(e.currentTarget.value)}>
          <option value="">ประเภท: ทั้งหมด ▾</option>
          {MATERIALS.map((m) => <option key={m.id} value={m.id}>{m.title}</option>)}
        </select>
        {hasFilters && (
          <button class="chip" style={{ color: 'var(--accent)' }}
            onClick={() => { setMemberF(''); setBrandF(''); setMaterialF(''); setStatusF(null) }}>
            ล้างตัวกรอง
          </button>
        )}
      </div>

      {weeks.length === 0 && <Empty icon="🗂️" text="ไม่พบงานในเดือนนี้ตามตัวกรองที่เลือก" />}
      {weeks.map((w) => (
        <div key={w.id}>
          <div class="section-title">{w.title}</div>
          <div class="list">
            {w.tasks.map((t) => <TaskRow key={t.id} task={t} onOpen={openTask} />)}
          </div>
        </div>
      ))}
    </div>
  )
}

function TaskDetail({ taskId, onBack, onEdit }) {
  const state = useStore()
  const [userName] = useUserName()
  const [newItem, setNewItem] = useState('')
  const [newComment, setNewComment] = useState('')
  const task = state.tasks.find((t) => t.id === taskId)

  if (!task) {
    return (
      <div class="overlay"><div class="screen no-tabbar">
        <TopBar small title="" left={<button class="icon-btn" onClick={onBack}>‹ กลับ</button>} />
        <Empty icon="🗑️" text="ไม่พบงานนี้ งานอาจถูกลบไปแล้ว" />
      </div></div>
    )
  }

  const member = store.member(task.assigneeID)
  const brand = store.brand(task.brandID)
  const next = nextStatus(task.status)
  const done = task.checklist.filter((c) => c.isDone).length
  const comments = [...task.comments].sort((a, b) => a.createdAt - b.createdAt)

  const addItem = () => {
    const title = newItem.trim()
    if (!title) return
    store.setChecklist(task, [...task.checklist, { id: uuid(), title, isDone: false }])
    setNewItem('')
  }
  const addComment = () => {
    const text = newComment.trim()
    if (!text) return
    store.addComment(task, { id: uuid(), text, author: userName || 'ไม่ระบุชื่อ', createdAt: new Date() })
    setNewComment('')
  }
  const link = (label, url) => {
    const href = webURL(url)
    return (
      <div class="row">
        <span class="grow">{label}</span>
        {href
          ? <a href={href} target="_blank" rel="noreferrer">เปิด ↗</a>
          : <button class="icon-btn" style={{ minHeight: 0, padding: 0 }} onClick={() => onEdit(task)}>+ เพิ่มลิงก์</button>}
      </div>
    )
  }

  return (
    <div class="overlay">
      <div class="screen no-tabbar">
        <TopBar small title="รายละเอียดงาน"
          left={<button class="icon-btn" onClick={onBack}>‹ กลับ</button>}
          right={<button class="icon-btn" onClick={() => onEdit(task)}>แก้ไข</button>} />

        <div class="card">
          <h2 style={{ margin: '0 0 8px' }}>{task.title}</h2>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <StatusPill id={task.status} />
            {isOverdue(task) && <span class="danger small">⚠️ เลยกำหนด</span>}
          </div>
          <div class="small muted" style={{ marginTop: 6 }}>อัปเดตล่าสุด {fmtRelative(task.updatedAt)}</div>
        </div>

        <div class="list">
          <Field label="สถานะ">
            <select value={task.status} onChange={(e) => store.setStatus(task, e.currentTarget.value)}>
              {STATUSES.map((s) => <option key={s.id} value={s.id}>{s.title}</option>)}
            </select>
          </Field>
          {next && (
            <button class="row" style={{ color: 'var(--accent)' }} onClick={() => store.setStatus(task, next.id)}>
              → ย้ายไป "{next.title}"
            </button>
          )}
        </div>

        <div class="section-title plain">รายละเอียด</div>
        <div class="list">
          <div class="row"><span class="grow">ผู้รับผิดชอบ</span>
            {member ? <><Avatar name={member.name} colorIndex={member.colorIndex} size={24} /><span>{member.name}</span></> : <span class="muted">ยังไม่มอบหมาย</span>}
          </div>
          <div class="row"><span class="grow">กำหนดส่ง</span><span class="muted">{fmtFull(task.dueDate)}</span></div>
          <div class="row"><span class="grow">ประเภทงาน</span><span class="muted">{material(task.material).title}</span></div>
          <div class="row"><span class="grow">ขั้นตอน</span><span class="muted">{ACTIONS.find((a) => a.id === task.action)?.title}</span></div>
          <div class="row"><span class="grow">แบรนด์ / ลูกค้า</span><span class="muted">{brand?.name ?? '-'}</span></div>
        </div>

        <div class="section-title plain">ไฟล์งาน</div>
        <div class="list">
          {link('Materials', task.materialsURL)}
          {link('Output', task.outputURL)}
        </div>

        <div class="section-title plain">จำนวนครั้งที่แก้ไข</div>
        <div class="list">
          {[['ลูกค้า', 'clientRevisions'], ['ภายใน', 'internalRevisions']].map(([label, key]) => (
            <div class="row" key={key}>
              <span class="grow">{label}: <b>{task[key]}</b></span>
              <button class="chip" style={{ background: 'var(--line)' }} disabled={task[key] <= 0}
                onClick={() => store.updateTask(task, { [key]: task[key] - 1 })}>−</button>
              <button class="chip" style={{ background: 'var(--line)' }}
                onClick={() => store.updateTask(task, { [key]: task[key] + 1 })}>＋</button>
            </div>
          ))}
        </div>

        <div class="section-title plain">เช็กลิสต์ ({done}/{task.checklist.length})</div>
        <div class="list">
          {task.checklist.map((item) => (
            <div class="row" key={item.id}>
              <button class={`check ${item.isDone ? 'done' : ''}`}
                onClick={() => store.setChecklist(task, task.checklist.map((c) => c.id === item.id ? { ...c, isDone: !c.isDone } : c))}>
                {item.isDone ? '✓' : ''}
              </button>
              <span class={`grow ${item.isDone ? 'done-text' : ''}`}>{item.title}</span>
              <button class="icon-btn" style={{ color: 'var(--muted)' }}
                onClick={() => store.setChecklist(task, task.checklist.filter((c) => c.id !== item.id))}>✕</button>
            </div>
          ))}
          <div class="row input-row">
            <input placeholder="เพิ่มขั้นตอน..." value={newItem} onInput={(e) => setNewItem(e.currentTarget.value)}
              onKeyDown={(e) => e.key === 'Enter' && addItem()} />
            <button class="icon-btn" disabled={!newItem.trim()} onClick={addItem}>＋</button>
          </div>
        </div>

        <div class="section-title plain">ความคิดเห็น ({task.comments.length})</div>
        <div class="list">
          {comments.map((c) => (
            <div class="row" key={c.id} style={{ alignItems: 'flex-start' }}>
              <div class="grow">
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <b class="small">{c.author}</b>
                  <span class="small muted">{fmtRelative(c.createdAt)}</span>
                </div>
                <div>{c.text}</div>
              </div>
              <button class="icon-btn" style={{ color: 'var(--muted)', minHeight: 0 }}
                onClick={() => confirm('ลบความคิดเห็นนี้?') && store.setComments(task, task.comments.filter((x) => x.id !== c.id))}>✕</button>
            </div>
          ))}
          <div class="row input-row">
            <input placeholder="เขียนความคิดเห็น..." value={newComment} onInput={(e) => setNewComment(e.currentTarget.value)}
              onKeyDown={(e) => e.key === 'Enter' && addComment()} />
            <button class="icon-btn" disabled={!newComment.trim()} onClick={addComment}>ส่ง</button>
          </div>
        </div>

        {task.notes && (
          <>
            <div class="section-title plain">โน้ต</div>
            <div class="card" style={{ whiteSpace: 'pre-wrap', marginTop: 0 }}>{task.notes}</div>
          </>
        )}

        <button class="btn destructive" onClick={() => {
          if (confirm('ลบงานนี้?')) {
            store.deleteTask(task)
            onBack()
          }
        }}>ลบงานนี้</button>
      </div>
    </div>
  )
}

function TaskEditor({ task, defaultDate, onClose }) {
  const state = useStore()
  const isNew = !task
  const [draft, setDraft] = useState(() => task ?? newTask({ dueDate: defaultDate ?? new Date() }))
  const set = (patch) => setDraft((d) => ({ ...d, ...patch }))
  const canSave = draft.title.trim().length > 0

  const save = () => {
    let out = {
      ...draft,
      title: draft.title.trim(),
      materialsURL: draft.materialsURL.trim(),
      outputURL: draft.outputURL.trim(),
    }
    const latest = !isNew && store.task(out.id)
    if (latest) {
      // Keep checklist/comments/revisions a teammate may have changed while this form was open.
      out = { ...out, checklist: latest.checklist, comments: latest.comments,
        clientRevisions: latest.clientRevisions, internalRevisions: latest.internalRevisions }
    }
    store.saveTask(out)
    onClose()
  }

  return (
    <div class="overlay modal">
      <div class="screen no-tabbar">
        <TopBar small title={isNew ? 'งานใหม่' : 'แก้ไขงาน'}
          left={<button class="icon-btn" onClick={onClose}>ยกเลิก</button>}
          right={<button class="icon-btn" style={{ fontWeight: 600 }} disabled={!canSave} onClick={save}>บันทึก</button>} />

        <div class="list" style={{ marginTop: 12 }}>
          <label class="row input-row">
            <input placeholder="ชื่องาน" value={draft.title} onInput={(e) => set({ title: e.currentTarget.value })} />
          </label>
          <Field label="กำหนดส่ง">
            <input type="date" value={toInputDate(draft.dueDate)}
              onChange={(e) => e.currentTarget.value && set({ dueDate: fromInputDate(e.currentTarget.value) })} />
          </Field>
        </div>

        <div class="list" style={{ marginTop: 16 }}>
          <Field label="ผู้รับผิดชอบ">
            <select value={draft.assigneeID ?? ''} onChange={(e) => set({ assigneeID: e.currentTarget.value || null })}>
              <option value="">ยังไม่มอบหมาย</option>
              {state.members.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
            </select>
          </Field>
          <Field label="แบรนด์ / ลูกค้า">
            <select value={draft.brandID ?? ''} onChange={(e) => set({ brandID: e.currentTarget.value || null })}>
              <option value="">ไม่ระบุ</option>
              {BRAND_KINDS.map((k) => (
                <optgroup key={k.id} label={k.title}>
                  {state.brands.filter((b) => b.kind === k.id).map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
                </optgroup>
              ))}
            </select>
          </Field>
        </div>

        <div class="list" style={{ marginTop: 16 }}>
          <Field label="ประเภทงาน">
            <select value={draft.material} onChange={(e) => set({ material: e.currentTarget.value })}>
              {MATERIALS.map((m) => <option key={m.id} value={m.id}>{m.title}</option>)}
            </select>
          </Field>
          <Field label="ขั้นตอน">
            <select value={draft.action} onChange={(e) => set({ action: e.currentTarget.value })}>
              {ACTIONS.map((a) => <option key={a.id} value={a.id}>{a.title}</option>)}
            </select>
          </Field>
          <Field label="สถานะ">
            <select value={draft.status} onChange={(e) => set({ status: e.currentTarget.value })}>
              {STATUSES.map((s) => <option key={s.id} value={s.id}>{s.title}</option>)}
            </select>
          </Field>
        </div>

        <div class="section-title plain">ลิงก์ไฟล์</div>
        <div class="list">
          <label class="row input-row">
            <input type="url" inputMode="url" autocapitalize="off" placeholder="ลิงก์ Materials" value={draft.materialsURL}
              onInput={(e) => set({ materialsURL: e.currentTarget.value })} />
          </label>
          <label class="row input-row">
            <input type="url" inputMode="url" autocapitalize="off" placeholder="ลิงก์ Output" value={draft.outputURL}
              onInput={(e) => set({ outputURL: e.currentTarget.value })} />
          </label>
        </div>

        <div class="section-title plain">โน้ต</div>
        <div class="list">
          <label class="row input-row">
            <textarea placeholder="รายละเอียดเพิ่มเติม" value={draft.notes} onInput={(e) => set({ notes: e.currentTarget.value })} />
          </label>
        </div>
      </div>
    </div>
  )
}

// ---------- To-Do ----------

function TodoScreen({ onEdit }) {
  const todos = useTodos()
  const [title, setTitle] = useState('')
  const open = todos.filter((t) => !t.isDone).sort((a, b) =>
    b.priority - a.priority
    || (a.dueDate && b.dueDate ? a.dueDate - b.dueDate : a.dueDate ? -1 : b.dueDate ? 1 : b.createdAt - a.createdAt))
  const done = todos.filter((t) => t.isDone).sort((a, b) => (b.completedAt ?? 0) - (a.completedAt ?? 0))

  const add = () => {
    const t = title.trim()
    if (!t) return
    todoStore.add(t)
    setTitle('')
  }

  const row = (t) => {
    const p = priority(t.priority)
    const overdue = !t.isDone && t.dueDate && t.dueDate < startOfDay(new Date())
    return (
      <div class="row" key={t.id} onClick={() => onEdit(t)} role="button">
        <button class={`check ${t.isDone ? 'done' : ''}`} style={{ color: t.isDone ? undefined : p.color }}
          onClick={(e) => { e.stopPropagation(); todoStore.toggle(t.id) }}>
          {t.isDone ? '✓' : ''}
        </button>
        <div class="grow">
          <div class={t.isDone ? 'done-text' : ''}>{t.title}</div>
          <div class="task-sub">
            {t.dueDate && <span class={overdue ? 'danger' : ''}>📅 {fmtDayMonth(t.dueDate)}</span>}
            {t.priority === 2 && !t.isDone && <span class="danger">🚩 สำคัญ</span>}
            {t.notes && <span>📝</span>}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div class="screen">
      <TopBar title="To-Do" right={done.length > 0 && (
        <button class="icon-btn" style={{ fontSize: 14 }} onClick={() => confirm('ลบรายการที่เสร็จแล้วทั้งหมด?') && todoStore.remove(done.map((t) => t.id))}>
          ล้างที่เสร็จ
        </button>
      )} />
      <div class="small muted" style={{ marginBottom: 8 }}>รายการส่วนตัว เก็บไว้ในเครื่องนี้เท่านั้น</div>
      <div class="list">
        <div class="row input-row">
          <span style={{ color: 'var(--accent)', fontSize: 22 }}>＋</span>
          <input placeholder="เพิ่มสิ่งที่ต้องทำ..." enterkeyhint="done" value={title}
            onInput={(e) => setTitle(e.currentTarget.value)} onKeyDown={(e) => e.key === 'Enter' && add()} />
        </div>
      </div>
      <div class="section-title plain">ต้องทำ ({open.length})</div>
      <div class="list">
        {open.length === 0 ? <div class="row muted">✅ ทำครบหมดแล้ว!</div> : open.map(row)}
      </div>
      {done.length > 0 && (
        <>
          <div class="section-title plain">เสร็จแล้ว ({done.length})</div>
          <div class="list">{done.map(row)}</div>
        </>
      )}
    </div>
  )
}

function TodoEditor({ todo, onClose }) {
  const [draft, setDraft] = useState(todo)
  const set = (patch) => setDraft((d) => ({ ...d, ...patch }))
  const save = () => {
    todoStore.update(todo.id, {
      ...draft,
      title: draft.title.trim() || todo.title,
      completedAt: draft.isDone === todo.isDone ? todo.completedAt : draft.isDone ? new Date() : null,
    })
    onClose()
  }
  return (
    <div class="overlay modal">
      <div class="screen no-tabbar">
        <TopBar small title="แก้ไข To-Do"
          left={<button class="icon-btn" onClick={onClose}>ยกเลิก</button>}
          right={<button class="icon-btn" style={{ fontWeight: 600 }} onClick={save}>บันทึก</button>} />
        <div class="list" style={{ marginTop: 12 }}>
          <label class="row input-row">
            <input value={draft.title} onInput={(e) => set({ title: e.currentTarget.value })} />
          </label>
          <Field label="เสร็จแล้ว">
            <span class="grow" />
            <input type="checkbox" style={{ flex: 'none', width: 22, height: 22 }} checked={draft.isDone}
              onChange={(e) => set({ isDone: e.currentTarget.checked })} />
          </Field>
        </div>
        <div class="segmented">
          {PRIORITIES.map((p) => (
            <button key={p.id} class={draft.priority === p.id ? 'on' : ''} onClick={() => set({ priority: p.id })}>
              ความสำคัญ{p.title}
            </button>
          ))}
        </div>
        <div class="list">
          <Field label="กำหนดวัน">
            <span class="grow" />
            <input type="checkbox" style={{ flex: 'none', width: 22, height: 22 }} checked={!!draft.dueDate}
              onChange={(e) => set({ dueDate: e.currentTarget.checked ? draft.dueDate ?? new Date() : null })} />
          </Field>
          {draft.dueDate && (
            <Field label="วันที่">
              <input type="date" value={toInputDate(draft.dueDate)}
                onChange={(e) => e.currentTarget.value && set({ dueDate: fromInputDate(e.currentTarget.value) })} />
            </Field>
          )}
        </div>
        <div class="section-title plain">โน้ต</div>
        <div class="list">
          <label class="row input-row">
            <textarea placeholder="รายละเอียด" value={draft.notes} onInput={(e) => set({ notes: e.currentTarget.value })} />
          </label>
        </div>
        <button class="btn destructive" onClick={() => { todoStore.remove([todo.id]); onClose() }}>ลบรายการนี้</button>
      </div>
    </div>
  )
}

// ---------- Calendar ----------

function CalendarScreen({ state, openTask, newTaskAt, onEditTodo }) {
  const todos = useTodos()
  const [selected, setSelected] = useState(startOfDay(new Date()))
  const [month, setMonth] = useState(startOfMonth(new Date()))
  const gridStart = startOfWeek(month)
  const days = Array.from({ length: 42 }, (_, i) => addDays(gridStart, i))
  const today = startOfDay(new Date())

  const dayTasks = state.tasks.filter((t) => sameDay(t.dueDate, selected))
  const dayTodos = todos.filter((t) => t.dueDate && sameDay(t.dueDate, selected))

  return (
    <div class="screen">
      <TopBar title="ปฏิทิน" right={<button class="icon-btn big" onClick={() => newTaskAt(selected)}>＋</button>} />
      <div class="cal">
        <div class="cal-head">
          <button class="icon-btn" onClick={() => setMonth(addMonths(month, -1))}>‹</button>
          <strong>{fmtMonthYear(month)}</strong>
          <button class="icon-btn" onClick={() => setMonth(addMonths(month, 1))}>›</button>
        </div>
        <div class="cal-grid">
          {['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'].map((d) => <div class="wd" key={d}>{d}</div>)}
          {days.map((d) => {
            const marks = state.tasks.filter((t) => sameDay(t.dueDate, d)).slice(0, 3)
            const cls = [
              d.getMonth() !== month.getMonth() && 'other',
              sameDay(d, today) && 'today',
              sameDay(d, selected) && 'sel',
            ].filter(Boolean).join(' ')
            return (
              <button key={d.getTime()} class={cls} onClick={() => setSelected(d)}>
                {d.getDate()}
                <span class="marks">{marks.map((t) => <i key={t.id} style={{ background: status(t.status).color }} />)}</span>
              </button>
            )
          })}
        </div>
      </div>
      <button class="btn secondary" style={{ margin: '8px 0' }}
        onClick={() => { setSelected(today); setMonth(startOfMonth(today)) }}>วันนี้</button>

      <div class="section-title plain">{fmtFull(selected)}</div>
      <div class="list">
        {dayTasks.length === 0 && dayTodos.length === 0 && <div class="row muted">ไม่มีงานในวันนี้</div>}
        {dayTasks.map((t) => <TaskRow key={t.id} task={t} onOpen={openTask} showNext={false} />)}
        {dayTodos.map((t) => (
          <div class="row" key={t.id} onClick={() => onEditTodo(t)} role="button">
            <button class={`check ${t.isDone ? 'done' : ''}`} style={{ color: t.isDone ? undefined : priority(t.priority).color }}
              onClick={(e) => { e.stopPropagation(); todoStore.toggle(t.id) }}>{t.isDone ? '✓' : ''}</button>
            <span class={`grow ${t.isDone ? 'done-text' : ''}`}>{t.title}</span>
            <span class="pill" style={{ background: 'var(--line)' }}>To-Do</span>
          </div>
        ))}
      </div>
    </div>
  )
}

// ---------- Settings ----------

function SettingsScreen({ state, onEditMember, onEditBrand }) {
  const [userName, setUserName] = useUserName()
  const [copied, setCopied] = useState(false)

  const shareInvite = async () => {
    const url = store.inviteLink()
    const text = `เข้าร่วมทีม "${state.teamName}" ในแอพ Team Tasks\nรหัสทีม: ${state.teamCode}\n${url}`
    try {
      if (navigator.share) {
        await navigator.share({ title: 'Team Tasks', text })
        return
      }
    } catch {
      return // User closed the share sheet.
    }
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      prompt('คัดลอกลิงก์นี้', url)
    }
  }

  return (
    <div class="screen">
      <TopBar title="ตั้งค่า" />

      <div class="section-title plain">ทีม</div>
      <div class="list">
        <div class="row"><span class="grow">ชื่อทีม</span><span class="muted">{state.teamName}</span></div>
        <div class="row"><span class="grow">รหัสทีม</span><span class="code">{state.teamCode}</span></div>
        <button class="row" style={{ color: 'var(--accent)' }} onClick={shareInvite}>
          {copied ? '✓ คัดลอกแล้ว' : '📤 แชร์ลิงก์เชิญเพื่อนร่วมทีม'}
        </button>
      </div>
      <p class="small muted" style={{ margin: '6px 4px' }}>
        ลิงก์เชิญจะตั้งค่า Firebase และกรอกรหัสทีมให้เพื่อนอัตโนมัติ ใครมีรหัสทีมจะเห็นและแก้ไขงานของทีมได้ แชร์ให้เฉพาะคนในทีม
      </p>

      <div class="section-title plain">โปรไฟล์</div>
      <div class="list">
        <label class="row input-row">
          <input placeholder="ชื่อของคุณ (ใช้แสดงในความคิดเห็น)" value={userName} onInput={(e) => setUserName(e.currentTarget.value)} />
        </label>
      </div>

      <div class="section-title plain">สมาชิกทีม</div>
      <div class="list">
        {state.members.map((m) => (
          <button class="row" key={m.id} onClick={() => onEditMember(m)}>
            <Avatar name={m.name} colorIndex={m.colorIndex} size={32} />
            <div class="grow">
              <div>{m.name}</div>
              {m.role && <div class="small muted">{m.role}</div>}
            </div>
            <span class="chev">›</span>
          </button>
        ))}
        <button class="row" style={{ color: 'var(--accent)' }} onClick={() => onEditMember(null)}>＋ เพิ่มสมาชิก</button>
      </div>

      {BRAND_KINDS.map((k) => (
        <div key={k.id}>
          <div class="section-title plain">{k.title}</div>
          <div class="list">
            {state.brands.filter((b) => b.kind === k.id).map((b) => (
              <button class="row" key={b.id} onClick={() => onEditBrand(b, k.id)}>
                <i class="dot" style={{ background: paletteColor(b.colorIndex), width: 10, height: 10 }} />
                <span class="grow">{b.name}</span>
                <span class="small muted">{state.tasks.filter((t) => t.brandID === b.id).length} งาน</span>
                <span class="chev">›</span>
              </button>
            ))}
            <button class="row" style={{ color: 'var(--accent)' }} onClick={() => onEditBrand(null, k.id)}>＋ เพิ่ม{k.title}</button>
          </div>
        </div>
      ))}

      <div class="section-title plain">ข้อมูล</div>
      <div class="list">
        <button class="row" style={{ color: 'var(--accent)' }} onClick={() => store.loadSampleData()}>โหลดข้อมูลตัวอย่าง</button>
        <button class="row danger" onClick={() => confirm('ลบงาน สมาชิก และแบรนด์ทั้งหมดของทีม? ทุกคนในทีมจะไม่เห็นข้อมูลนี้อีก') && store.deleteAllTeamData()}>
          ลบข้อมูลทั้งหมดของทีม
        </button>
        <button class="row danger" onClick={() => confirm(`ออกจากทีม? กลับเข้ามาได้ด้วยรหัส ${state.teamCode}`) && store.leaveTeam()}>
          ออกจากทีมนี้
        </button>
        <button class="row danger" onClick={() => confirm('ล้างการตั้งค่า Firebase ในเครื่องนี้?') && store.resetConfig()}>
          ล้างการตั้งค่า Firebase
        </button>
      </div>
    </div>
  )
}

function MemberEditor({ member, onClose }) {
  const [draft, setDraft] = useState(() => member ?? { id: uuid(), name: '', role: '', colorIndex: Math.floor(Math.random() * 10) })
  const set = (patch) => setDraft((d) => ({ ...d, ...patch }))
  const canSave = draft.name.trim()
  return (
    <div class="overlay modal">
      <div class="screen no-tabbar">
        <TopBar small title={member ? 'แก้ไขสมาชิก' : 'สมาชิกใหม่'}
          left={<button class="icon-btn" onClick={onClose}>ยกเลิก</button>}
          right={<button class="icon-btn" style={{ fontWeight: 600 }} disabled={!canSave}
            onClick={() => { store.saveMember({ ...draft, name: draft.name.trim(), role: draft.role.trim() }); onClose() }}>บันทึก</button>} />
        <div class="empty" style={{ padding: 16 }}><Avatar name={draft.name} colorIndex={draft.colorIndex} size={72} /></div>
        <div class="list">
          <label class="row input-row"><input placeholder="ชื่อ" value={draft.name} onInput={(e) => set({ name: e.currentTarget.value })} /></label>
          <label class="row input-row"><input placeholder="ตำแหน่ง" value={draft.role} onInput={(e) => set({ role: e.currentTarget.value })} /></label>
        </div>
        <div class="section-title plain">สี</div>
        <div class="list"><ColorPicker value={draft.colorIndex} onChange={(i) => set({ colorIndex: i })} /></div>
        {member && (
          <button class="btn destructive" onClick={() => {
            if (confirm(`ลบ ${member.name} ออกจากทีม?`)) {
              store.deleteMember(member)
              onClose()
            }
          }}>ลบสมาชิก</button>
        )}
      </div>
    </div>
  )
}

function BrandEditor({ brand, kind, onClose }) {
  const [draft, setDraft] = useState(() => brand ?? { id: uuid(), name: '', kind, colorIndex: Math.floor(Math.random() * 10) })
  const set = (patch) => setDraft((d) => ({ ...d, ...patch }))
  const canSave = draft.name.trim()
  return (
    <div class="overlay modal">
      <div class="screen no-tabbar">
        <TopBar small title={brand ? 'แก้ไข' : 'เพิ่มใหม่'}
          left={<button class="icon-btn" onClick={onClose}>ยกเลิก</button>}
          right={<button class="icon-btn" style={{ fontWeight: 600 }} disabled={!canSave}
            onClick={() => { store.saveBrand({ ...draft, name: draft.name.trim() }); onClose() }}>บันทึก</button>} />
        <div class="list" style={{ marginTop: 12 }}>
          <label class="row input-row">
            <input placeholder="ชื่อแบรนด์ / ลูกค้า" value={draft.name} onInput={(e) => set({ name: e.currentTarget.value })} />
          </label>
        </div>
        <div class="segmented">
          {BRAND_KINDS.map((k) => (
            <button key={k.id} class={draft.kind === k.id ? 'on' : ''} onClick={() => set({ kind: k.id })}>{k.title}</button>
          ))}
        </div>
        <div class="section-title plain">สี</div>
        <div class="list"><ColorPicker value={draft.colorIndex} onChange={(i) => set({ colorIndex: i })} /></div>
        {brand && (
          <button class="btn destructive" onClick={() => {
            if (confirm(`ลบ ${brand.name}?`)) {
              store.deleteBrand(brand)
              onClose()
            }
          }}>ลบ</button>
        )}
      </div>
    </div>
  )
}

// ---------- Shell ----------

const TABS = [
  { id: 'dashboard', title: 'ภาพรวม', icon: '▦' },
  { id: 'tasks', title: 'งานทีม', icon: '☰' },
  { id: 'todo', title: 'To-Do', icon: '☑︎' },
  { id: 'calendar', title: 'ปฏิทิน', icon: '📅' },
  { id: 'settings', title: 'ตั้งค่า', icon: '⚙︎' },
]

function MainApp({ state }) {
  const [tab, setTab] = useState(() => read('tab', 'dashboard'))
  const [taskId, setTaskId] = useState(null)
  const [taskEditor, setTaskEditor] = useState(null) // { task, defaultDate }
  const [todoEditing, setTodoEditing] = useState(null)
  const [memberEditing, setMemberEditing] = useState(undefined) // undefined = closed, null = new
  const [brandEditing, setBrandEditing] = useState(null) // { brand, kind }

  const selectTab = (id) => {
    setTab(id)
    write('tab', id)
    window.scrollTo(0, 0)
  }

  const shared = {
    state,
    openTask: setTaskId,
    newTaskAt: (date) => setTaskEditor({ task: null, defaultDate: date }),
  }

  return (
    <>
      {tab === 'dashboard' && <Dashboard {...shared} />}
      {tab === 'tasks' && <TasksScreen {...shared} />}
      {tab === 'todo' && <TodoScreen onEdit={setTodoEditing} />}
      {tab === 'calendar' && <CalendarScreen {...shared} onEditTodo={setTodoEditing} />}
      {tab === 'settings' && (
        <SettingsScreen state={state} onEditMember={setMemberEditing} onEditBrand={(brand, kind) => setBrandEditing({ brand, kind })} />
      )}

      <nav class="tabbar">
        {TABS.map((t) => (
          <button key={t.id} class={tab === t.id ? 'on' : ''} onClick={() => selectTab(t.id)}>
            <span class="ico">{t.icon}</span>
            {t.title}
          </button>
        ))}
      </nav>

      {taskId && <TaskDetail taskId={taskId} onBack={() => setTaskId(null)} onEdit={(task) => setTaskEditor({ task })} />}
      {taskEditor && <TaskEditor task={taskEditor.task} defaultDate={taskEditor.defaultDate} onClose={() => setTaskEditor(null)} />}
      {todoEditing && <TodoEditor todo={todoEditing} onClose={() => setTodoEditing(null)} />}
      {memberEditing !== undefined && <MemberEditor member={memberEditing} onClose={() => setMemberEditing(undefined)} />}
      {brandEditing && <BrandEditor brand={brandEditing.brand} kind={brandEditing.kind} onClose={() => setBrandEditing(null)} />}
    </>
  )
}

function App() {
  const state = useStore()
  useEffect(() => {
    store.start()
  }, [])

  let content
  switch (state.phase) {
    case 'needsConfig':
      content = <ConfigSetup />
      break
    case 'needsTeam':
      content = <TeamSetup />
      break
    case 'failed':
      content = (
        <div class="screen no-tabbar">
          <Empty icon="📡" text={`เชื่อมต่อไม่สำเร็จ: ${state.error}`} />
          <button class="btn" onClick={() => store.start()}>ลองอีกครั้ง</button>
          <button class="btn destructive" onClick={() => store.resetConfig()}>ตั้งค่า Firebase ใหม่</button>
        </div>
      )
      break
    case 'ready':
      content = <MainApp state={state} />
      break
    default:
      content = <div class="screen no-tabbar"><Empty icon="⏳" text="กำลังเชื่อมต่อ..." /></div>
  }

  return (
    <>
      {content}
      {state.lastError && (
        <div class="toast">
          <span class="grow">⚠️ {state.lastError}</span>
          <button onClick={() => store.set({ lastError: null })}>ปิด</button>
        </div>
      )}
    </>
  )
}

render(<App />, document.getElementById('app'))
