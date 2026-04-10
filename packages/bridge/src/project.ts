// ============================================================
// project.ts — Project Manager
// يُنشئ ويدير مجلدات المشاريع على الجهاز (cross-platform)
// ============================================================

import { mkdirSync, writeFileSync, existsSync, readFileSync } from 'fs'
import { join, resolve, normalize, sep } from 'path'
import os from 'os'
import { randomUUID } from 'crypto'

// ─── Types ───

export interface Project {
  id:           string
  name:         string
  path:         string        // المسار الموحّد (forward slashes)
  description?: string
  instructions: string        // محتوى CLAUDE.md
  createdAt:    number
  updatedAt:    number
}

// ─── Storage (JSON بسيط) ───

const CONFIG_DIR    = join(os.homedir(), '.ccpocket')
const PROJECTS_FILE = join(CONFIG_DIR, 'projects.json')
const BASE_DIR      = join(os.homedir(), 'ccpocket-projects')

function ensureConfigDir(): void {
  if (!existsSync(CONFIG_DIR)) mkdirSync(CONFIG_DIR, { recursive: true })
}

function loadProjectsFile(): Project[] {
  try {
    if (!existsSync(PROJECTS_FILE)) return []
    return JSON.parse(readFileSync(PROJECTS_FILE, 'utf-8')) as Project[]
  } catch {
    return []
  }
}

function saveProjectsFile(projects: Project[]): void {
  ensureConfigDir()
  writeFileSync(PROJECTS_FILE, JSON.stringify(projects, null, 2), 'utf-8')
}

// ─── Cross-platform path normalization ───
// يحوّل المسارات لـ forward slashes دائماً (JSON-safe)
function normalizePath(p: string): string {
  return normalize(resolve(p)).split(sep).join('/')
}

// ─── Windows path support — يقبل كلا الصيغتين ───
function sanitizeName(name: string): string {
  // يزيل الأحرف غير الصالحة في أسماء المجلدات (Windows + Unix)
  return name.replace(/[/\\:*?"<>|]/g, '_').trim()
}

// ============================================================
// ProjectManager
// ============================================================

export class ProjectManager {
  // ── إنشاء مشروع جديد ──
  create(opts: {
    name:          string
    path?:         string
    instructions?: string
    description?:  string
  }): Project {
    const safeName    = sanitizeName(opts.name)
    const projectPath = opts.path
      ? normalizePath(opts.path)
      : normalizePath(join(BASE_DIR, safeName))

    // إنشاء المجلد
    const rawPath = projectPath.split('/').join(sep)
    if (!existsSync(rawPath)) {
      mkdirSync(rawPath, { recursive: true })
    }

    // إنشاء .claude/
    const claudeDir = join(rawPath, '.claude')
    if (!existsSync(claudeDir)) {
      mkdirSync(claudeDir, { recursive: true })
    }

    // كتابة CLAUDE.md
    const instructions = opts.instructions ??
      `# ${opts.name}\n\nمشروع تم إنشاؤه عبر CCPocket Universal.\n\n## التعليمات\n\nاكتب هنا تعليمات خاصة بهذا المشروع للـ AI.\n`
    writeFileSync(join(rawPath, 'CLAUDE.md'), instructions, 'utf-8')

    const project: Project = {
      id:           randomUUID(),
      name:         opts.name,
      path:         projectPath,
      description:  opts.description,
      instructions,
      createdAt:    Date.now(),
      updatedAt:    Date.now(),
    }

    const projects = loadProjectsFile()
    projects.push(project)
    saveProjectsFile(projects)

    console.log(`[Projects] Created: "${project.name}" @ ${project.path}`)
    return project
  }

  // ── ربط مجلد موجود ──
  link(opts: {
    path:          string
    name:          string
    description?:  string
    instructions?: string
  }): Project {
    const projectPath = normalizePath(opts.path)
    const rawPath     = projectPath.split('/').join(sep)

    if (!existsSync(rawPath)) {
      throw new Error(`المجلد غير موجود: ${rawPath}`)
    }

    // اقرأ CLAUDE.md الموجود أو أنشئه
    const claudeMdPath = join(rawPath, 'CLAUDE.md')
    let instructions   = opts.instructions ?? ''
    if (existsSync(claudeMdPath)) {
      instructions = readFileSync(claudeMdPath, 'utf-8')
    } else if (instructions) {
      writeFileSync(claudeMdPath, instructions, 'utf-8')
    }

    const project: Project = {
      id:           randomUUID(),
      name:         opts.name,
      path:         projectPath,
      description:  opts.description,
      instructions,
      createdAt:    Date.now(),
      updatedAt:    Date.now(),
    }

    const projects = loadProjectsFile()
    projects.push(project)
    saveProjectsFile(projects)

    console.log(`[Projects] Linked: "${project.name}" @ ${project.path}`)
    return project
  }

  // ── قائمة المشاريع (الأحدث أولاً) ──
  list(): Project[] {
    return loadProjectsFile().sort((a, b) => b.updatedAt - a.updatedAt)
  }

  // ── جلب مشروع ──
  get(projectId: string): Project | null {
    return loadProjectsFile().find((p) => p.id === projectId) ?? null
  }

  // ── حذف من القائمة فقط (لا يحذف الملفات) ──
  remove(projectId: string): boolean {
    const projects = loadProjectsFile()
    const idx = projects.findIndex((p) => p.id === projectId)
    if (idx === -1) return false
    const [removed] = projects.splice(idx, 1)
    saveProjectsFile(projects)
    console.log(`[Projects] Removed: "${removed.name}"`)
    return true
  }

  // ── تحديث CLAUDE.md ──
  updateInstructions(projectId: string, instructions: string): Project | null {
    const projects = loadProjectsFile()
    const project  = projects.find((p) => p.id === projectId)
    if (!project) return null

    project.instructions = instructions
    project.updatedAt    = Date.now()

    // حدّث الملف على الـ disk
    try {
      const rawPath = project.path.split('/').join(sep)
      writeFileSync(join(rawPath, 'CLAUDE.md'), instructions, 'utf-8')
    } catch (e) {
      console.warn(`[Projects] Could not write CLAUDE.md: ${e}`)
    }

    saveProjectsFile(projects)
    return project
  }
}

// ─── Singleton ───
export const projectManager = new ProjectManager()
