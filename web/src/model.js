// Same data shapes and raw values as the iOS app (TaskTracker/Models/Models.swift),
// so both apps read and write the same Firestore documents.

export const STATUSES = [
  { id: 'inProgress', title: 'กำลังทำ', color: '#1a73e8' },
  { id: 'forReview', title: 'รอตรวจ', color: '#e8710a' },
  { id: 'scheduled', title: 'ตั้งเวลาแล้ว', color: '#8e44d4' },
  { id: 'posted', title: 'โพสต์แล้ว', color: '#1e8e3e' },
]

export const ACTIONS = [
  { id: 'create', title: 'สร้าง' },
  { id: 'schedule', title: 'ตั้งเวลา' },
  { id: 'post', title: 'โพสต์' },
]

export const MATERIALS = [
  { id: 'copywriting', title: 'Copywriting' },
  { id: 'staticDesign', title: 'Static design' },
  { id: 'carousel', title: 'Carousel design' },
  { id: 'reel', title: 'Reel / video' },
  { id: 'slides', title: 'Slides' },
  { id: 'other', title: 'อื่นๆ' },
]

export const BRAND_KINDS = [
  { id: 'inHouse', title: 'แบรนด์ในเครือ' },
  { id: 'client', title: 'ลูกค้า' },
]

export const PRIORITIES = [
  { id: 0, title: 'ต่ำ', color: '#8e8e93' },
  { id: 1, title: 'ปกติ', color: '#1a73e8' },
  { id: 2, title: 'สูง', color: '#d93025' },
]

// Mirrors Palette.colors in the iOS app (index-based, so colours match across apps).
export const PALETTE = [
  '#007aff', '#ff2d55', '#5856d6', '#34c759', '#ff9500',
  '#af52de', '#30b0c7', '#ff3b30', '#a2845e', '#00c7be',
]

export const paletteColor = (i) => PALETTE[((i % PALETTE.length) + PALETTE.length) % PALETTE.length]

const byId = (list) => (id) => list.find((x) => x.id === id) ?? list[0]
export const status = byId(STATUSES)
export const action = byId(ACTIONS)
export const material = byId(MATERIALS)
export const brandKind = byId(BRAND_KINDS)
export const priority = byId(PRIORITIES)

export function nextStatus(id) {
  const i = STATUSES.findIndex((s) => s.id === id)
  return i >= 0 && i < STATUSES.length - 1 ? STATUSES[i + 1] : null
}

export const uuid = () => crypto.randomUUID().toUpperCase()

// ---------- Dates (weeks start on Monday, like the iOS app) ----------

export const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate())
export const startOfMonth = (d) => new Date(d.getFullYear(), d.getMonth(), 1)
export const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n)
export const addMonths = (d, n) => new Date(d.getFullYear(), d.getMonth() + n, 1)
export const sameDay = (a, b) => startOfDay(a).getTime() === startOfDay(b).getTime()
export const sameMonth = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth()

export function startOfWeek(d) {
  const day = (d.getDay() + 6) % 7 // Monday = 0
  return addDays(startOfDay(d), -day)
}

export const isThisWeek = (d) => startOfWeek(d).getTime() === startOfWeek(new Date()).getTime()

export function isOverdue(task) {
  return task.status !== 'posted' && task.dueDate < startOfDay(new Date())
}

const fmt = (opts) => new Intl.DateTimeFormat('th-TH', opts)
export const fmtDayMonth = (d) => fmt({ day: 'numeric', month: 'short' }).format(d)
export const fmtMonthYear = (d) => fmt({ month: 'long', year: 'numeric' }).format(d)
export const fmtFull = (d) => fmt({ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(d)
export const toInputDate = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
export function fromInputDate(s) {
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d, 10)
}

export function fmtRelative(d) {
  const rtf = new Intl.RelativeTimeFormat('th', { numeric: 'auto' })
  const secs = Math.round((d.getTime() - Date.now()) / 1000)
  const units = [
    ['year', 31536000], ['month', 2592000], ['week', 604800],
    ['day', 86400], ['hour', 3600], ['minute', 60],
  ]
  for (const [unit, size] of units) {
    if (Math.abs(secs) >= size) return rtf.format(Math.round(secs / size), unit)
  }
  return 'เมื่อสักครู่'
}

/** Groups a month's tasks into Monday-based weeks clipped to the month, like WeekGroup in the iOS app. */
export function weekGroups(tasks, month) {
  const monthStart = startOfMonth(month)
  const monthLast = addDays(addMonths(month, 1), -1)
  const groups = new Map()
  for (const t of tasks) {
    const key = startOfWeek(t.dueDate).getTime()
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push(t)
  }
  return [...groups.keys()].sort((a, b) => a - b).map((key) => {
    const weekStart = new Date(key)
    const start = weekStart < monthStart ? monthStart : weekStart
    const weekEnd = addDays(weekStart, 6)
    const end = weekEnd > monthLast ? monthLast : weekEnd
    const number = Math.floor((start.getDate() - 1 + ((monthStart.getDay() + 6) % 7)) / 7) + 1
    return {
      id: key,
      title: `สัปดาห์ ${number} | ${fmtDayMonth(start)} – ${fmtDayMonth(end)}`,
      tasks: groups.get(key).sort((a, b) => a.dueDate - b.dueDate),
    }
  })
}

export function webURL(s) {
  const t = (s ?? '').trim()
  if (!t) return null
  return t.includes('://') ? t : `https://${t}`
}

// ---------- Sample data (same as SampleData.swift) ----------

export function sampleTeamData() {
  const m = (name, role, colorIndex) => ({ id: uuid(), name, role, colorIndex })
  const b = (name, kind, colorIndex) => ({ id: uuid(), name, kind, colorIndex })
  const hannah = m('Hannah', 'Digital Marketing Manager', 2)
  const erianne = m('Erianne', 'Graphic Designer', 1)
  const donald = m('Donald', 'Content Creator', 0)
  const patrick = m('Patrick', 'Video Editor', 3)

  const jysigma = b('JYSigma Business Consultancy', 'inHouse', 0)
  const jca = b('JCA', 'inHouse', 2)
  const gthRise = b('GTH Rise', 'inHouse', 5)
  const gthAsia = b('GTH Asia', 'inHouse', 6)
  const jbc = b('JBC', 'inHouse', 4)
  const jackYang = b('Jack Yang', 'inHouse', 8)
  const seah = b('Seah Engineering', 'client', 6)
  const eclipse = b('Eclipse Steakhouse', 'client', 8)

  const now = new Date()
  const day = (d) => new Date(now.getFullYear(), now.getMonth(), d, 10)
  const link = 'https://drive.google.com'

  const task = (title, d, st, act, mat, member, brand, { output = false, checklist = [], comments = [] } = {}) =>
    newTask({
      title,
      dueDate: day(d),
      status: st,
      action: act,
      material: mat,
      assigneeID: member.id,
      brandID: brand.id,
      materialsURL: link,
      outputURL: output ? link : '',
      checklist: checklist.map((title, i) => ({ id: uuid(), title, isDone: i === 0 })),
      comments: comments.map((text) => ({ id: uuid(), text, author: member.name, createdAt: new Date() })),
    })

  const tasks = [
    task('Launch announcement copy', 1, 'posted', 'create', 'copywriting', hannah, gthRise,
      { output: true, checklist: ['ร่างข้อความ', 'ส่งให้ลูกค้าตรวจ'], comments: ['ลูกค้าอนุมัติแล้ว'] }),
    task('Private dinner ad visual', 1, 'forReview', 'create', 'staticDesign', erianne, jbc,
      { output: true, checklist: ['ทำ 2 เวอร์ชัน', 'ปรับสีตาม CI'], comments: ['ขอปรับโทนสี', 'แก้ไขแล้ว', 'รอลูกค้าดู'] }),
    task('Aircon tips carousel', 2, 'scheduled', 'schedule', 'carousel', donald, seah,
      { output: true, comments: ['ตั้งเวลาโพสต์ 18:00', 'โอเค'] }),
    task('Founder story reel', 2, 'inProgress', 'create', 'reel', patrick, jackYang,
      { checklist: ['ตัดต่อ', 'ใส่ซับไตเติล', 'ใส่เพลง'], comments: ['รอฟุตเทจเพิ่ม'] }),
    task('Services carousel', 5, 'inProgress', 'create', 'carousel', erianne, jca,
      { checklist: ['วางเลย์เอาต์', 'ใส่ไอคอน'] }),
    task('Q4 update post', 6, 'posted', 'post', 'staticDesign', donald, gthAsia, { output: true }),
    task('Investor explainer slides', 8, 'inProgress', 'create', 'slides', hannah, jbc,
      { checklist: ['โครงเรื่อง', 'ออกแบบสไลด์', 'ตรวจตัวเลข'] }),
    task('Steakhouse weekend promo', 14, 'forReview', 'create', 'staticDesign', erianne, eclipse),
    task('Consultancy LinkedIn article', 20, 'inProgress', 'create', 'copywriting', hannah, jysigma,
      { checklist: ['หาข้อมูล', 'เขียนร่างแรก'] }),
    task('Halloween reel', 27, 'scheduled', 'schedule', 'reel', patrick, gthRise, { output: true }),
  ]

  return {
    members: [hannah, erianne, donald, patrick],
    brands: [jysigma, jca, gthRise, gthAsia, jbc, jackYang, seah, eclipse],
    tasks,
  }
}

export function newTask(fields = {}) {
  const now = new Date()
  return {
    id: uuid(),
    title: '',
    notes: '',
    dueDate: now,
    status: 'inProgress',
    action: 'create',
    material: 'copywriting',
    assigneeID: null,
    brandID: null,
    materialsURL: '',
    outputURL: '',
    clientRevisions: 0,
    internalRevisions: 0,
    checklist: [],
    comments: [],
    createdAt: now,
    updatedAt: now,
    ...fields,
  }
}
