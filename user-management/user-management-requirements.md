## AVMS — User Management Requirements (Frontend + Backend)

This document captures concrete, implementable requirements for the AVMS User Management module, aligned with our current stack and codebase:

- Frontend: Angular (guards, interceptors, shared components)
- Backend: NestJS + Mongoose (MongoDB), JWT authentication
- Current primitives in code: Users, Roles (with `permissions: string[]`), JWT guard with permission checks, Company/Project/Task modules present

V1 focuses on a pragmatic permission model using flat permission flags (present in the JWT). V2 extends to module-level permissions with company scoping (assigned/specific/all) and richer audit/governance.


### 1) Scope & assumptions
- **App type**: Multi-tenant internal app for an actuarial firm (single org today; multi-org-ready later).
- **Personas**: Org Admin, Team Manager, Team Member, (optional) Client User.
- **Module coverage**: Identity & invites, roles & permissions, company access, team management, tasking, audit visibility.
- **Frontend responsibilities**: UX/routing/guards, validation, client-side state, access gating. Backed by REST APIs.


### 2) Personas & role model (UI-level)
- **Org Admin**: Org-wide management; manages users/roles, teams, companies, modules.
- **Team Manager**: Manages team membership and work; visibility limited to allowed companies/modules.
- **Team Member**: Executes tasks/projects; visibility limited to allowed companies/modules.
- **Client User (optional)**: Read-only access to their company’s data/reports.

Mapping (V1): roles map to a set of permission flags; JWT includes `permissions: string[]`. Example role → permissions:
- Org Admin → `*` (or comprehensive superset across modules)
- Team Manager → `manage_projects`, `manage_tasks`, `view_companies`, `view_reports`
- Team Member → `view_projects`, `view_tasks`, `view_companies`, `view_reports`


### 3) Information architecture & navigation
- **People**
  - Users
  - Teams
  - Access
  - Company Access Matrix
  - Module Permissions / Role Templates
- **Work**
  - Projects
  - Tasks / My Tasks
- **Governance**
  - Audit Log
  - Settings

Provide a persistent top-bar context switcher: Role (if multi-role) • Team • Company • Project (optional).


### 4) Permission model (UI rules)
V1 (as implemented in backend today):
- Use flat permission flags from JWT claim `permissions: string[]` enforced server-side by `PermissionAuthGuard`.
- UI routes and controls gate on these flags (hide routes; disable controls).

Suggested standard permission flags (expand as needed):
- Users: `manage_users`, `view_users`
- Roles: `manage_roles`, `view_roles`
- Companies: `manage_companies`, `view_companies`
- Projects: `manage_projects`, `view_projects`
- Tasks: `manage_tasks`, `view_tasks`
- Reports: `view_reports`
- Settings: `manage_settings`, `view_settings`

V2 (roadmap):
- Two-axes model per module: `level ∈ {none, view, edit, admin}` × `scope ∈ {none, assigned, specific, all}` with company scoping.
- Effective permission = max(level across grants) ∩ company scope. UI hides routes and disables controls accordingly.


### 5) Route guards & visibility (Angular)
- Guards check: `isAuthenticated`, `hasPermission(permFlag)`; in V2 also `hasModulePermission(moduleKey, level, companyScope)`.
- If blocked: show Not Authorized empty state with optional “Request access” or route to safe default (Dashboard/Projects).
- Interceptors: attach JWT, base URL, and loader indicators (already present in app).


### 6) Key screens & components

#### A) Users list
- Table columns: Name, Email, Role(s), Team(s), Status (Active/Invited/Suspended), Companies (count), Modules (summary), Last sign-in.
- Controls: search (name/email), filters (role, team, status), sort (name, last sign-in), pagination, bulk actions (assign role, assign companies, deactivate).
- Row actions: View, Edit, Impersonate/View-as (Admin), Suspend/Activate, Reset MFA (if used).

#### B) Invite / add user flow
- Steps: Identity → Team assignment → Company access → Module permissions/template.
- Inline validation; preview effective access; “Send invite” vs “Create without email” (SSO path).
- Success: toast + redirect to user profile.

#### C) User profile
- Tabs: Overview | Teams | Companies | Modules | Activity.
- Overview: roles, status, last sign-in, MFA status.
- Teams: add/remove (autocomplete); show inherited company access.
- Companies: chips/list with source (Direct / Via Team); add/remove (Admin).
- Modules: per-module selector; show source & overrides. V1: show as derived from role permissions.
- Activity: recent actions (audit API, read-only).

#### D) Teams
- Teams table: Name, Manager(s), Members, Companies (count), Projects (count).
- Team detail: basics, members management, company assignment, default module template (applied to new members).

#### E) Company Access Matrix
- Grid: Rows = Users/Teams; Columns = Companies; Cell = Access badge (None/Assigned).
- Toggle Users | Teams; filters: company group, team, role; virtualized.
- Bulk select cells → Assign/Remove.

#### F) Module permissions
- Table per module: Subject (User/Team), Scope (All/Assigned/Specific), Level (None/View/Edit/Admin).
- Bulk edit: apply template to selected.

#### G) Projects & Tasks (team manager/member)
- Projects list: Company, Period, Status, Manager, Team.
- Task board (Kanban): To Do / In Progress / For Review / Done.
- Task fields: Title, Project, Company, Module, Assignee(s), Due date, Priority, Checklist, Attachments, Comments.
- Filters: my tasks, by company, by module, by due, by status; bulk move; quick assign.
- Visibility gated by permissions (V1: flags; V2: module+company scope).

#### H) Audit Log (read-only)
- Table: Time, Actor, Action, Target (user/team/company/module), Before/After (diff), Source IP.
- Filters: actor, action type; row click opens side panel with JSON diff.

#### I) Settings (Org Admin)
- Role templates management; default permissions for new users.
- Invitation settings (expiry, email text preview).
- SSO badge & MFA requirements indicators.


### 7) Workflows (acceptance-style)
- Invite employee: Admin invites with team(s), module permissions/template, company scope; user appears as Invited and on acceptance gains access.
- Assign companies to Team Manager: Admin adds companies to team; Team Managers inherit visibility and can assign tasks.
- Grant module access to employee: Admin updates module levels and scope; UI reflects in nav & controls.
- Team Manager assigns tasks: Only members with access to selected module/company are assignable and will see tasks.
- Access request (optional): Member requests access; Manager/Admin approves/denies; routing updates.


### 8) Component inventory (reusable)
- DataGrid (virtualized, bulk select, column config, CSV export)
- DualListAssigner (companies ↔ users/teams)
- PermissionSelector (None/View/Edit/Admin + scope dropdown)
- RoleTemplatePicker
- EntityChips with source badges (Direct / Via Team)
- ContextSwitcher (Role/Team/Company/Project)
- KanbanBoard
- AuditDiffViewer
- InviteWizard
- ConfirmationDialogs (with type DELETE to confirm)


### 9) State, loading & errors (UX guarantees)
- Optimistic updates where safe (e.g., team membership) with rollback.
- Skeleton loaders; toasts for success/failure; empty states with CTAs.
- Conflict handling: inline banner with reason when backend denies update.


### 10) Validation (client-side)
- Email format + best-effort uniqueness.
- Require at least one role or module permission when inviting.
- If scope ≠ “All Companies”, require at least one company (or team with companies).
- Prevent reducing your own access below page’s requirement (soft guard + confirm).


### 11) Non-functional (frontend)
- Accessibility: keyboardable grids, ARIA, focus management for modals.
- Performance: virtualized lists, chunked company lists, debounced search.
- Internationalization: all labels i18n; RTL-safe layouts.
- Theming: light/dark; high-contrast mode.
- Telemetry: events for invites, grants, revokes, task moves; performance timings.


### 12) Data shapes (view-models; illustrative)

```ts
type ModuleKey = 'dataIntake' | 'valuations' | 'reports' | 'billing' | 'settings';
type PermLevel = 'none' | 'view' | 'edit' | 'admin';

interface UserVM {
  id: string; name: string; email: string; status: 'active'|'invited'|'suspended';
  roles: string[]; teams: string[]; lastSignInAt?: string;
  companyIds: string[];
  modulePerms: Record<ModuleKey, { level: PermLevel; scope: 'none'|'assigned'|'specific'|'all'; companyIds?: string[] }>;
}

interface TeamVM {
  id: string; name: string; managers: string[]; members: string[];
  companyIds: string[]; defaultPermTemplate?: string;
}

interface CompanyVM { id: string; name: string; tags?: string[]; }

interface ProjectVM { id: string; companyId: string; period: string; status: 'open'|'closed'; managerId: string; }

interface TaskVM {
  id: string; projectId: string; companyId: string; module: ModuleKey;
  title: string; assigneeIds: string[]; status: 'todo'|'inProgress'|'review'|'done';
  dueDate?: string; priority?: 'low'|'med'|'high';
}
```

Note: In V1, derive `modulePerms` from role permissions; in V2, fetch per-user effective permissions.


---

## Backend — Requirements aligned to NestJS + Mongoose (current code)

### 1) Architecture & tenancy
- Single org today; prepare for multi-org by including `orgId` in documents (future migration).
- Services (logical): Auth/Identity, Directory (users/roles), Access Control (permissions), Companies, Work Management (projects/tasks), Audit.
- Data store: MongoDB (Mongoose). Caching (Redis) optional in V2 for permission caching.


### 2) Domain model (collections)

Users & Roles (present today)
- `users` { _id, name, email[unique], password[hash], verified, role[ObjectId Role], verificationKey }
- `roles` { _id, name[unique], permissions[string[]] }

Companies (present today in company module)
- `companies` { _id, name, code, tags[], active, createdAt, updatedAt }

Work Management (present today)
- `projects`, `tasks`, `project_files` (schemas/controllers exist)

Roadmap V2 (to support scoped ABAC)
- `teams` { _id, name, description, managerIds[], memberIds[] }
- `team_companies` { teamId, companyId }
- `user_companies` { userId, companyId, source: 'direct' }
- `permission_grants` { subjectType: 'user'|'team', subjectId, moduleKey, level, scope, companyIds? }
- `audit_events` { occurredAt, actorUserId, action, targetType, targetId, before, after }


### 3) Permission model (V1: RBAC via flags; V2: module + scoped)

V1 (current)
- Role → `permissions[]` (e.g., `manage_projects`, `view_reports`).
- JWT includes `permissions` claim; `PermissionAuthGuard` checks required permissions via `@SetMetadata('permissions', [...])`.

V2 (roadmap)
- Grants of shape: (subject, moduleKey, level, scope, companyIds?).
- Level order: none < view < edit < admin. Scopes: all | assigned | specific.
- Effective permission computed from union/max across subject + team grants.


### 4) API surface (present and planned)

Auth (present)
- POST `/auth/login` → `{ accessToken }`
- POST `/auth/refresh-token` (JWT guard)
- POST `/auth/logout`

Users (present)
- GET `/users` → list
- GET `/users/:id` → detail
- POST `/users` → create (requires role existence)
- PUT `/users/:id` → update
- DELETE `/users/:id` → remove
- POST `/users/password/new` → set password with `verificationKey`

Roles (present)
- GET `/roles`
- GET `/roles/:id`
- POST `/roles`
- PUT `/roles/:id`
- DELETE `/roles/:id`

Companies (present)
- GET `/companies`, GET `/companies/:id`, PATCH `/companies/:id`

Projects & Tasks (present)
- Projects: CRUD and domain actions (valuation endpoints). Secure via permission metadata e.g., `manage_projects`.
- Tasks: CRUD (controller present in file-management; ensure permissions applied).

Planned (V2)
- Teams: CRUD; manage members and managers.
- Access: PUT `/users/:id/companies`, PUT `/teams/:id/companies`.
- Permissions: PUT `/users/:id/permissions` (module/scoped); GET effective-permissions.
- Audit: GET `/audit` with filtering; all mutating endpoints emit audit events.


### 5) AuthN & AuthZ plumbing
- Tokens: JWT access; refresh-token path available (today via `/auth/refresh-token`).
- Guard: `PermissionAuthGuard` verifies JWT and checks required permissions.
- Controllers should declare permissions via `@UseGuards(PermissionAuthGuard)` + `@SetMetadata('permissions', [...])`.
- Impersonation (view-as) optional; admin-only + audited.


### 6) Write-path rules & integrity
- User creation requires valid role ID; validate unique email.
- Password setup via `verificationKey` path; ensure one-time semantics.
- Role mutation updates should reflect in new JWTs (user re-login required); V2 may add permission cache invalidation.
- Deletion guards: block deletion of teams with active grants/projects (V2).


### 7) Performance & scaling
- Index `users.email` (unique), `roles.name` (unique), common list filters.
- Server-side pagination and filtering for users/roles/companies/projects.
- Consider Redis caching for effective permissions in V2.


### 8) Security & compliance
- Hash passwords; never return password fields.
- Strict validation on all DTOs (Joi pipe present); continue enforcing schema.
- Rate-limit auth endpoints (login/invite accept when added).
- JWT secret from configuration; short access token TTL recommended.


### 9) Observability
- Structured logs on auth and user/role mutations.
- Metrics (V2): login success/failure, permission changes, API latencies.
- Tracing (V2): DB operations and external calls.


### 10) Backoffice & seeding
- Seed default roles with permissions:
  - Org Admin: superset of all permission flags
  - Team Manager: manage projects/tasks; view companies/reports
  - Team Member: view projects/tasks/companies/reports
- Bootstrap first Org Admin user via admin script with a secure password and verified=true.


### 11) Example payloads

User create (V1)
```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "role": "<roleObjectId>"
}
```

Role create
```json
{
  "name": "Team Manager",
  "permissions": ["manage_projects", "manage_tasks", "view_companies", "view_reports"]
}
```

Login
```json
{
  "email": "jane@example.com",
  "password": "<secret>"
}
```


### 12) Acceptance criteria (V1)
- Unauthorized routes are not reachable (deep-link test); guards use JWT and permission flags.
- Users grid supports search, filters, bulk edit, CSV export.
- Invite wizard enforces sane defaults and previews effective access.
- Module permission changes (role permissions) reflect immediately in visible nav & controls after next login/token refresh.
- Team Manager can create project and assign tasks if role grants allow.
- Team Member sees only routes enabled by permission flags; cannot access protected APIs (403 by guard).
- All screens meet accessibility basics; lists have loading/empty/error states.


### 13) V2 roadmap items
- Scoped module permissions with company access (assigned/specific/all) and effective permission cache.
- Company Access Matrix with large-scale virtualization and bulk assign/remove.
- Audit log and append-only events for all mutations.
- Access requests workflow and approvals.
- Saved views per user, permission simulations (View as), bulk import for users/company assignments.


