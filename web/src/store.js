// Web counterpart of TeamStore.swift: same Firestore layout (teams/{code}/members|brands|tasks).
import { initializeApp } from 'firebase/app'
import { connectAuthEmulator, getAuth, onAuthStateChanged, signInAnonymously } from 'firebase/auth'
import {
  arrayUnion,
  collection,
  connectFirestoreEmulator,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  initializeFirestore,
  onSnapshot,
  persistentLocalCache,
  persistentMultipleTabManager,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore'
import { useEffect, useState } from 'preact/hooks'
import { sampleTeamData, uuid } from './model.js'

const CONFIG_KEY = 'firebaseConfig'
const TEAM_KEY = 'teamCode'

const read = (key) => {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}
const write = (key, value) => {
  try {
    if (value == null) localStorage.removeItem(key)
    else localStorage.setItem(key, value)
  } catch {
    // Private mode etc. — the app still works for this session.
  }
}

/** Pulls apiKey/projectId/... out of the snippet Firebase shows (`const firebaseConfig = {...}`) or plain JSON. */
export function parseFirebaseConfig(text) {
  const config = {}
  for (const [, key, value] of text.matchAll(/["']?(\w+)["']?\s*:\s*["']([^"']+)["']/g)) {
    config[key] = value
  }
  if (!config.apiKey || !config.projectId || !config.appId) return null
  return config
}

const toDate = (v) => (v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : new Date(v ?? Date.now()))

function decodeTask(data) {
  return {
    notes: '',
    materialsURL: '',
    outputURL: '',
    clientRevisions: 0,
    internalRevisions: 0,
    ...data,
    assigneeID: data.assigneeID ?? null,
    brandID: data.brandID ?? null,
    dueDate: toDate(data.dueDate),
    createdAt: toDate(data.createdAt),
    updatedAt: toDate(data.updatedAt),
    checklist: data.checklist ?? [],
    comments: (data.comments ?? []).map((c) => ({ ...c, createdAt: toDate(c.createdAt) })),
  }
}

/** Optional ids are left out when empty, matching how the iOS app encodes nil. */
function encodeTask(task) {
  const out = { ...task }
  if (!out.assigneeID) delete out.assigneeID
  if (!out.brandID) delete out.brandID
  return out
}

const byName = (a, b) => a.name.localeCompare(b.name, 'th')

class TeamStore {
  state = {
    phase: 'starting', // starting | needsConfig | needsTeam | ready | failed
    error: null,
    lastError: null,
    teamCode: read(TEAM_KEY) ?? '',
    teamName: '',
    members: [],
    brands: [],
    tasks: [],
  }

  listeners = new Set()
  unsubscribers = []
  db = null
  auth = null

  subscribe(fn) {
    this.listeners.add(fn)
    return () => this.listeners.delete(fn)
  }

  set(patch) {
    this.state = { ...this.state, ...patch }
    this.listeners.forEach((fn) => fn(this.state))
  }

  report = (error) => {
    console.error(error)
    this.set({ lastError: error?.message ?? String(error) })
  }

  get config() {
    try {
      return JSON.parse(read(CONFIG_KEY) ?? 'null')
    } catch {
      return null
    }
  }

  saveConfig(config) {
    write(CONFIG_KEY, JSON.stringify(config))
  }

  async start() {
    const config = this.config
    if (!config) {
      this.set({ phase: 'needsConfig' })
      return
    }
    this.set({ phase: 'starting', error: null })
    try {
      if (!this.db) {
        const app = initializeApp(config)
        this.auth = getAuth(app)
        this.db = initializeFirestore(app, {
          localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
        })
        // ?emulator in the URL talks to local Firebase emulators (for testing only).
        if (new URLSearchParams(location.search).has('emulator')) {
          connectAuthEmulator(this.auth, 'http://127.0.0.1:9099', { disableWarnings: true })
          connectFirestoreEmulator(this.db, '127.0.0.1', 8080)
        }
      }
      await new Promise((resolve) => {
        const off = onAuthStateChanged(this.auth, () => {
          off()
          resolve()
        })
      })
      if (!this.auth.currentUser) await signInAnonymously(this.auth)
      if (this.state.teamCode) {
        this.attach()
        this.set({ phase: 'ready' })
      } else {
        this.set({ phase: 'needsTeam' })
      }
    } catch (error) {
      this.set({ phase: 'failed', error: error?.message ?? String(error) })
    }
  }

  /** Clears the saved Firebase project; a page reload is needed to init a different one. */
  resetConfig() {
    this.leaveTeam()
    write(CONFIG_KEY, null)
    location.reload()
  }

  // ---------- Team ----------

  teamRef(code = this.state.teamCode) {
    return doc(this.db, 'teams', code)
  }

  col(name) {
    return collection(this.db, 'teams', this.state.teamCode, name)
  }

  async createTeam({ name, yourName, withSampleData }) {
    const code = makeTeamCode()
    await setDoc(this.teamRef(code), { name, createdAt: Timestamp.now() })
    this.useTeam(code)
    const taken = withSampleData ? this.loadSampleData().map((m) => m.name) : []
    if (!taken.includes(yourName)) this.saveMember({ id: uuid(), name: yourName, role: '', colorIndex: randomColor() })
  }

  async joinTeam({ code: raw, yourName }) {
    const code = raw.trim().toUpperCase()
    if (!code) throw new Error('ไม่พบทีมนี้ ตรวจสอบรหัสทีมอีกครั้ง')
    const snap = await getDoc(this.teamRef(code))
    if (!snap.exists()) throw new Error('ไม่พบทีมนี้ ตรวจสอบรหัสทีมอีกครั้ง')
    const existing = await getDocs(
      query(collection(this.db, 'teams', code, 'members'), where('name', '==', yourName))
    )
    this.useTeam(code)
    if (existing.empty) this.saveMember({ id: uuid(), name: yourName, role: '', colorIndex: randomColor() })
  }

  useTeam(code) {
    write(TEAM_KEY, code)
    this.set({ teamCode: code })
    this.attach()
    this.set({ phase: 'ready' })
  }

  leaveTeam() {
    this.detach()
    write(TEAM_KEY, null)
    this.set({ teamCode: '', teamName: '', members: [], brands: [], tasks: [], phase: 'needsTeam' })
  }

  attach() {
    this.detach()
    this.unsubscribers.push(
      onSnapshot(this.teamRef(), (snap) => this.set({ teamName: snap.data()?.name ?? '' }), this.report),
      onSnapshot(this.col('members'), (snap) => {
        this.set({ members: snap.docs.map((d) => d.data()).sort(byName) })
      }, this.report),
      onSnapshot(this.col('brands'), (snap) => {
        this.set({ brands: snap.docs.map((d) => d.data()).sort(byName) })
      }, this.report),
      onSnapshot(this.col('tasks'), (snap) => {
        this.set({ tasks: snap.docs.map((d) => decodeTask(d.data())).sort((a, b) => a.dueDate - b.dueDate) })
      }, this.report),
    )
  }

  detach() {
    this.unsubscribers.forEach((off) => off())
    this.unsubscribers = []
  }

  // ---------- Lookups ----------

  member(id) {
    return id ? this.state.members.find((m) => m.id === id) : undefined
  }

  brand(id) {
    return id ? this.state.brands.find((b) => b.id === id) : undefined
  }

  task(id) {
    return this.state.tasks.find((t) => t.id === id)
  }

  // ---------- Writes (applied locally first, synced in the background) ----------

  saveTask(task) {
    setDoc(doc(this.col('tasks'), task.id), encodeTask({ ...task, updatedAt: new Date() })).catch(this.report)
  }

  deleteTask(task) {
    deleteDoc(doc(this.col('tasks'), task.id)).catch(this.report)
  }

  /** Only touches the given fields so teammates editing other fields are not overwritten. */
  updateTask(task, fields) {
    updateDoc(doc(this.col('tasks'), task.id), { ...fields, updatedAt: new Date() }).catch(this.report)
  }

  setStatus(task, status) {
    this.updateTask(task, { status })
  }

  setChecklist(task, checklist) {
    this.updateTask(task, { checklist })
  }

  addComment(task, comment) {
    this.updateTask(task, { comments: arrayUnion(comment) })
  }

  setComments(task, comments) {
    this.updateTask(task, { comments })
  }

  saveMember(member) {
    setDoc(doc(this.col('members'), member.id), member).catch(this.report)
  }

  deleteMember(member) {
    deleteDoc(doc(this.col('members'), member.id)).catch(this.report)
  }

  saveBrand(brand) {
    setDoc(doc(this.col('brands'), brand.id), brand).catch(this.report)
  }

  deleteBrand(brand) {
    deleteDoc(doc(this.col('brands'), brand.id)).catch(this.report)
  }

  loadSampleData() {
    const data = sampleTeamData()
    const batch = writeBatch(this.db)
    data.members.forEach((m) => batch.set(doc(this.col('members'), m.id), m))
    data.brands.forEach((b) => batch.set(doc(this.col('brands'), b.id), b))
    data.tasks.forEach((t) => batch.set(doc(this.col('tasks'), t.id), encodeTask(t)))
    batch.commit().catch(this.report)
    return data.members
  }

  deleteAllTeamData() {
    const batch = writeBatch(this.db)
    this.state.tasks.forEach((t) => batch.delete(doc(this.col('tasks'), t.id)))
    this.state.members.forEach((m) => batch.delete(doc(this.col('members'), m.id)))
    this.state.brands.forEach((b) => batch.delete(doc(this.col('brands'), b.id)))
    batch.commit().catch(this.report)
  }

  /** A link that sets up a teammate's browser with this Firebase project and team code. */
  inviteLink() {
    const payload = btoa(unescape(encodeURIComponent(JSON.stringify({ c: this.config, t: this.state.teamCode }))))
    return `${location.origin}${location.pathname}#join=${payload}`
  }
}

/** Eight characters without look-alikes (0/O, 1/I), same as the iOS app. */
function makeTeamCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const bytes = crypto.getRandomValues(new Uint8Array(8))
  return [...bytes].map((b) => alphabet[b % alphabet.length]).join('')
}

const randomColor = () => Math.floor(Math.random() * 10)

/**
 * Reads an invite link (#join=...) if present: saves its Firebase config and returns the team code to prefill.
 */
export function consumeInviteLink() {
  const match = location.hash.match(/^#join=(.+)$/)
  if (!match) return null
  history.replaceState(null, '', location.pathname + location.search)
  try {
    const { c, t } = JSON.parse(decodeURIComponent(escape(atob(match[1]))))
    if (c?.apiKey) write(CONFIG_KEY, JSON.stringify(c))
    return t ?? null
  } catch {
    return null
  }
}

export const store = new TeamStore()

export function useStore() {
  const [state, setState] = useState(store.state)
  useEffect(() => store.subscribe(setState), [])
  return state
}

// ---------- Personal to-dos (this browser only) ----------

const TODOS_KEY = 'todos'

class TodoStore {
  todos = this.load()
  listeners = new Set()

  load() {
    try {
      const raw = JSON.parse(read(TODOS_KEY) ?? 'null')
      if (!raw) return null
      return raw.map((t) => ({
        ...t,
        dueDate: t.dueDate ? new Date(t.dueDate) : null,
        createdAt: new Date(t.createdAt),
        completedAt: t.completedAt ? new Date(t.completedAt) : null,
      }))
    } catch {
      return null
    }
  }

  subscribe(fn) {
    this.listeners.add(fn)
    return () => this.listeners.delete(fn)
  }

  commit(todos) {
    this.todos = todos
    write(TODOS_KEY, JSON.stringify(todos))
    this.listeners.forEach((fn) => fn(todos))
  }

  add(title, fields = {}) {
    this.commit([
      { id: uuid(), title, notes: '', isDone: false, dueDate: null, priority: 1, createdAt: new Date(), completedAt: null, ...fields },
      ...this.todos,
    ])
  }

  update(id, fields) {
    this.commit(this.todos.map((t) => (t.id === id ? { ...t, ...fields } : t)))
  }

  toggle(id) {
    const t = this.todos.find((x) => x.id === id)
    if (t) this.update(id, { isDone: !t.isDone, completedAt: t.isDone ? null : new Date() })
  }

  remove(ids) {
    const set = new Set(ids)
    this.commit(this.todos.filter((t) => !set.has(t.id)))
  }
}

export const todoStore = new TodoStore()

if (todoStore.todos === null) {
  // First run: a few example to-dos, like the iOS app.
  todoStore.todos = []
  const nextWeekday = (wd) => {
    const d = new Date()
    d.setHours(10, 0, 0, 0)
    while (d.getDay() !== wd) d.setDate(d.getDate() + 1)
    return d
  }
  todoStore.add('อัปเดตปฏิทินคอนเทนต์เดือนหน้า', { priority: 0 })
  todoStore.add('ขอไฟล์โลโก้ใหม่จาก Seah Engineering')
  todoStore.add('ประชุมทีมเช้าวันจันทร์', { dueDate: nextWeekday(1) })
  todoStore.add('สรุป KPI รายสัปดาห์ส่งหัวหน้า', { dueDate: nextWeekday(5), priority: 2 })
}

export function useTodos() {
  const [todos, setTodos] = useState(todoStore.todos)
  useEffect(() => todoStore.subscribe(setTodos), [])
  return todos
}
