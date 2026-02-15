### AVMS — Project Tasks (General)

Status legend: [Done], [In Progress], [Todo], [Backlog]

### Frontend (Angular)
- Auth & Guards
  - [Done] Auth guard with token refresh fallback
  - [Done] HTTP interceptors (auth, base URL, loader)
  - [Todo] Route-level permission checks using `permissions` flags
  - [Todo] Not Authorized empty state with Request Access button (optional)

- User Management UI
  - [Todo] Users list table (search, filters, sort, pagination, CSV export)
  - [Todo] Invite wizard (Identity → Teams → Company Access → Permissions template)
  - [Todo] User profile (Overview, Teams, Companies, Modules, Activity)

- Teams & Access (UI)
  - [Backlog] Teams list/detail (members, managers, companies)
  - [Backlog] Company Access Matrix (virtualized, bulk assign/remove)
  - [Backlog] Module Permissions page (per-module level + scope)

- Projects & Tasks UI
  - [Todo] Kanban board (To Do / In Progress / Review / Done) with filters & bulk move

- Audit & Settings UI
  - [Backlog] Audit Log (table + JSON diff side panel)
  - [Todo] Settings: role templates, defaults, invitation settings, SSO/MFA indicators

- UX Platform
  - [Todo] Skeleton loaders, toasts, empty states across lists
  - [Todo] i18n coverage; RTL-safe layouts
  - [Todo] Theming (light/dark, high-contrast)
  - [Backlog] Telemetry events and performance timings

### Backend (NestJS + MongoDB)
- Auth
  - [Done] Login with JWT; access/refresh token generation
  - [Todo] Finalize refresh-token contract (verify refresh; return new access token)
  - [Todo] Logout handler implementation
  - [Todo] Update `lastSignInAt` on login; add `status` to user (active/invited/suspended)

- User Management
  - [Done] Users schema & CRUD (Joi validation on create)
  - [Done] Roles schema & CRUD with `permissions: string[]`
  - [Todo] Seed default roles (Org Admin, Team Manager, Team Member) with permissions
  - [Todo] Invitations flow (create invite, single-use password set, email hook)

- Authorization
  - [Done] `PermissionAuthGuard` verifying JWT and permission flags
  - [Todo] Apply guard + `@SetMetadata('permissions', [...])` across protected controllers (projects, tasks, users, roles)

- Companies, Projects, Tasks
  - [Done] Core schemas/controllers present
  - [Todo] Enforce permission flags for CRUD and actions

- Teams & Scoped Access (V2)
  - [Backlog] Teams, team_companies, user_companies collections & services
  - [Backlog] `permission_grants` with moduleKey/level/scope (+ specific companies)
  - [Backlog] Effective permissions compute + cache (Redis optional) with invalidation

- Audit & Governance (V2)
  - [Backlog] `audit_events` collection and GET API
  - [Backlog] Emit audit entries on all mutations
  - [Backlog] Access requests workflow (create, approve/deny) & notifications

### DevOps & Quality
- [Todo] Rate limiting for auth/invite endpoints
- [Todo] Indexes for common queries (users.email, roles.name, list filters)
- [Backlog] Metrics/telemetry/tracing for key routes

### Acceptance Gates
- [Todo] Guards block unauthorized deep-links; protected APIs return 403
- [Todo] Users grid features validated (search, filters, bulk edit, CSV export)
- [Todo] Permission changes reflected after token refresh
- [Backlog] V2: Access Matrix, audit log, scoped permissions end-to-end


