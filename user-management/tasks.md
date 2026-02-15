### User Management — Tasks (AVMS)

This checklist reflects what’s already implemented vs. what remains, aligned to the SRS and current Angular/NestJS (Mongoose) code.

### Done (present in code)
- Backend
  - [x] Users: Mongoose schema with `name`, `email[unique]`, `password`, `verified`, `role:ObjectId`, `verificationKey`.
  - [x] Roles: Mongoose schema with `name[unique]`, `permissions: string[]`; CRUD endpoints.
  - [x] Users CRUD endpoints and validation on create (Joi pipe).
  - [x] JWT auth: login, refresh-token route stub, service generates access/refresh; permission guard (`PermissionAuthGuard`) exists.
  - [x] Companies, Projects, Tasks modules exist with core endpoints.
- Frontend
  - [x] Auth guard to check session and attempt token refresh.
  - [x] HTTP interceptors (auth, base-url, loader).

### Needs alignment/fixes (short-term)
- Backend
  - AuthController: unify responses and contract
    - Ensure `/auth/login` returns both `access_token` and `refresh_token`.
    - Fix `/auth/refresh-token` to accept/verify refresh token and return `{ access_token }`.
  - Apply `PermissionAuthGuard` + `@SetMetadata('permissions', [...])` on protected routes (projects, tasks, users, roles).
  - Add `lastSignInAt` update on successful login; add `status: active|invited|suspended` to users.
- Frontend
  - AuthService: align with new auth contracts (store/renew tokens, handle refresh failures gracefully).
  - Route-level permission checks (by perm flags) and Not Authorized empty state.

### V1 — Must deliver
- Backend
  - Users API enhancements
    - GET `/users`: pagination, search (name/email), filters (role, status), sort (name, lastSignInAt).
    - PATCH `/users/:id`: update name/status; suspend/activate endpoints or flags.
  - Roles API
    - Seed default roles and permission flags: Org Admin, Team Manager, Team Member.
  - Authorization
    - Enforce permission metadata across controllers; add tests for 403 on missing permissions.
  - Invitations (minimal)
    - Create “invite” path leveraging `verificationKey` + `status=invited` and email hook stub.
    - POST `/users/password/new` one-time semantics; invalidate key after use.
  - Audit (minimal)
    - Log auth and user/role mutations to app logs with actor and target.
- Frontend
  - Users
    - Users list: table (columns per SRS), search, filters, sort, pagination, CSV export.
    - Row actions: View, Edit, Suspend/Activate; (optional) Impersonate.
  - Invite wizard
    - Steps: Identity → Team assignment (placeholder) → Company access (placeholder) → Permissions template (role-based for V1).
    - Preview effective access; success toast + redirect.
  - User profile (V1)
    - Overview (role, status, last sign-in), basic edit.
  - Permissions UX
    - Route gating by `permissions` flags; disable controls for view-only.
  - Common UX
    - Not Authorized empty state; skeleton loaders; success/error toasts.

### V2 — Scoped access, teams, governance
- Backend
  - Teams & membership: collections and CRUD; team managers; team-companies; user-companies (direct).
  - Module permissions: `permission_grants` (user/team), levels (none/view/edit/admin), scopes (all/assigned/specific), effective computation.
  - Effective permissions cache (optional Redis) with invalidation on changes.
  - Audit events collection + API; emit events on all mutations.
  - Access requests workflow (create, approve/deny) and notifications hook.
- Frontend
  - Teams: list + detail (members, companies, managers), default permission template.
  - Company Access Matrix: virtualized grid, bulk assign/remove, filters.
  - Module Permissions: per-module table with bulk edit and templates.
  - Kanban Task Board: statuses (To Do/In Progress/Review/Done), filters, bulk move.
  - Audit Log: table + side panel JSON diff viewer.
  - Context Switcher: Role • Team • Company • Project.

### Non-functional & platform items
- Validation: strong DTO validation (continue Joi usage); client-side validation per SRS.
- Accessibility: keyboardable grids, ARIA on toggles, focus management.
- Performance: server-side pagination; virtualized lists; debounced search.
- Internationalization: wrap labels in i18n; ensure RTL-safe layouts.
- Theming: light/dark + high contrast.
- Telemetry: events for invites, grants, revokes, task moves; page performance timings.

### Acceptance checks
- Guards block unauthorized deep links; protected APIs return 403 with reason.
- Users grid supports search, filters, bulk edit, CSV export.
- Invite wizard validates and shows effective access preview.
- Permission changes reflect immediately in nav/controls after next token refresh.
- Team Manager can create projects and assign tasks within permissions (V1 by flags; V2 with scope).
- Member sees only in-scope routes/data.
- Loading, empty, and error states for all lists and detail views.


