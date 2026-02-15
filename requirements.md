## AVMS — Software Requirements Specification (SRS)

### Document Control
- **Product**: Actuarial Valuation Management System (AVMS)
- **Version**: 0.1 (Draft)
- **Status**: Draft for review
- **Owner**: AVMS Engineering
- **Last updated**: 2025-08-24

### Purpose
This SRS defines the functional and non-functional requirements for the AVMS platform that streamlines actuarial valuation projects, including company and project management, employee data handling, assumptions and benefit structures, valuation processing (batch and individual), and reporting. It covers the Angular frontend, the NestJS backend, and the FastAPI valuation service.

### Scope
- **Frontend**: Angular application for user interaction, workflows, and visualization of project stages and results.
- **Backend (Core API)**: NestJS service providing authentication, authorization, company/project/employee data management, file handling, and integration with the valuation service; MongoDB as the primary data store.
- **Valuation Service**: FastAPI microservice providing batch/individual valuation execution, progress tracking, and results storage/retrieval in MongoDB.

### Definitions and Acronyms
- **RBAC**: Role-Based Access Control
- **JWT**: JSON Web Token
- **AVMS**: Actuarial Valuation Management System
- **Active employee**: Employee currently in service
- **Pensioner employee**: Retired employee receiving pension
- **Project stage**: A step in a project lifecycle: Contract and Planning, Last Year Report and Results, Data, Assumptions, Benefits Structure, Valuation, Report, Invoicing, Correspondence, Completed

---

## 1. Overall Description

### 1.1 Product Perspective
AVMS is a multi-service web application:
- Angular SPA communicates with the NestJS backend via HTTP and interceptors for auth.
- NestJS backend provides domain APIs for users, roles/permissions, companies, projects, files, and employee data management, and integrates with the FastAPI valuation endpoints.
- FastAPI service runs valuation batches, stores individual employee results, and exposes status/progress endpoints.

### 1.2 User Classes and Roles
- **Admin**: Manages users, roles, permissions; full access to companies, projects, data, and valuations.
- **Actuary**: Manages projects, assumptions, benefits structures, and runs valuations; reads companies and employee data.
- **Analyst**: Manages employee data ingestion and validation; can initiate valuations as permitted.
- **Viewer**: Read-only access to assigned companies/projects and reports.

RBAC is implemented via roles with a set of permission strings (e.g., `manage_companies`, `read_companies`). Permissions are evaluated per endpoint on the backend using a JWT permission guard.

### 1.3 Operating Environment
- Web: Modern Chromium-based browsers, Safari, Firefox (latest two versions)
- Backend: Node.js (NestJS), MongoDB
- Valuation Service: Python (FastAPI), MongoDB

### 1.4 Constraints and Assumptions
- JWT must be configured with `JWT_SECRET`.
- MongoDB is the source of truth for master data and valuation results.
- Long-running valuations are executed asynchronously in the FastAPI service.

---

## 2. Functional Requirements

Each requirement includes a unique identifier for traceability. Acceptance criteria are provided for key requirements.

### 2.1 Authentication and Authorization
- **FR-AUTH-1 (Login)**: The system shall authenticate users via `POST /auth/login` and return a JWT `accessToken` for verified users.
  - Acceptance: Given valid credentials for a verified user, when logging in, then a 200 is returned with `accessToken`. Invalid or unverified users receive 401.
- **FR-AUTH-2 (Refresh Token)**: The system shall refresh JWT tokens via `POST /auth/refresh-token` for authenticated sessions.
  - Acceptance: With a valid bearer token, refresh returns a new `accessToken`.
- **FR-AUTH-3 (Logout)**: The system shall invalidate sessions via `POST /auth/logout`.
- **FR-AUTH-4 (RBAC Guard)**: Endpoints shall enforce permissions using a JWT permission guard.
  - Example: `GET /companies` requires `read_companies`; `POST /companies` requires `manage_companies`.
- **FR-AUTH-5 (Frontend Guard)**: Routes guarded in the frontend shall redirect unauthenticated users to the sign-in page and attempt token refresh before redirecting.

### 2.2 Role and User Management
- **FR-ROLE-1 (Role CRUD)**: Create, read, update, delete roles via `/roles` with fields: `name`, `permissions: string[]`.
  - Acceptance: Creating a role with unique `name` persists and is queryable with assigned `permissions`.
- **FR-USER-1 (User CRUD)**: Manage users (create/read/update/delete), including `name`, `email`, optional `password`, `verified`, and `role` reference.
- **FR-USER-2 (Verification Flag)**: Users must have `verified = true` to obtain tokens.
- **FR-USER-3 (Tokens)**: Store and manage user tokens with expiry for session control.

### 2.3 Company Management
- **FR-COMP-1 (Create Company)**: Create companies with `name`, unique `code`, and `contactPersons`.
  - Endpoint: `POST /companies` (requires `manage_companies`).
- **FR-COMP-2 (Read Companies)**: List and view company details.
  - Endpoint: `GET /companies` (requires `read_companies`), `GET /companies/:id`.
- **FR-COMP-3 (Update/Delete)**: Update and delete companies (requires `manage_companies`).

### 2.4 Project Management
- **FR-PROJ-1 (Project CRUD)**: Create/read/update projects with fields: `name`, `valuationDate`, `valuationType`, `stage`, `company`, `contactPerson`, and composite objects for `contract`, `lastYearInfo`, `requestedDataFiles`, `receivedDataFiles`, `compiledDataFiles`, `assumptions`, `benifitsStructure`, `valuations`.
- **FR-PROJ-2 (Stages Navigation)**: Frontend shall display project stages and render stage-specific components based on the active stage.
- **FR-PROJ-3 (Stage Transitions)**: Authorized users can progress a project through stages: Contract and Planning → Last Year Report and Results → Data → Assumptions → Benefits Structure → Valuation → Report → Invoicing → Correspondence → Completed.
  - Acceptance: Changing `stage` updates UI to corresponding component and persists to backend.

### 2.5 Employee Data Management
- **FR-EMP-1 (Active Employees CRUD)**: Manage active employees with fields: `SNO`, `ECODE`, `NAME`, `PAY_SCALE`, `DOA`, `DOB`, `PAY`, `AGE`, `PS`, `ORDERLY_ALLOWANCE`, optional `project`, `projectStage`.
  - Endpoints under `/active-employee-data` (create/read/update/delete; server-side validation via Joi; persistence in MongoDB collection `activeemployeedatas`).
- **FR-EMP-2 (Pensioner Employees CRUD)**: Manage pensioner employees with fields: `SNO`, `ECODE`, `NAME`, `TYPE_OF_PENSIONER`, `DOB`, `DOR`, `PENSION_AMOUNT`, `MEDICAL_ALLOWANCE`, `ORDERLY_ALLOWANCE`, `AGE_AT_RETIREMENT`, `AGE`, `YEARS_TO_RESTORATION`, `CURRENT_VALUE_OF_RESTORED_AMOUNT`, optional `project`, `projectStage`.
  - Endpoints under `/pensioner-employee-data` (server-side validation via Joi; persistence in MongoDB collection `pensioneremployeedatas`).
- **FR-EMP-3 (Query by Code)**: Retrieve a single employee record by `ECODE` for both active and pensioner data.
- **FR-EMP-4 (Project-Stage Association)**: All employee data entries can be associated with a `project` and `projectStage`.

### 2.6 File Management
- **FR-FILE-1 (Upload)**: The system shall allow uploading requested, received, and compiled data files per project and stage.
- **FR-FILE-2 (List/Download/Delete)**: List, download, and delete files associated with a project/stage.

### 2.7 Assumptions and Benefits Structure
- **FR-ASSUMP-1 (Assumptions Capture)**: Capture and persist stage-specific actuarial assumptions (e.g., decrement tables, discount rates) linked to a project.
- **FR-BEN-1 (Benefits Structure Capture)**: Capture and persist stage-specific benefits structure for gratuity, leave encashment, and pension plans.
- **FR-BEN-2 (Validation)**: Validate inputs (types and ranges) on both client and server.

### 2.8 Valuations and Tasks (FastAPI Integration)
- **FR-VAL-1 (Run Batch Valuation)**: Trigger batch valuation for a project stage.
  - Endpoint: `POST /api/v1/projects/{project_id}/valuations/{valuation_stage}/run-batch` with `batch_size`, `max_concurrent_batches`, and payload (e.g., `job_id`).
  - Acceptance: For a valid project and stage, request is accepted and results processed asynchronously.
- **FR-VAL-2 (Batch Status/Progress)**: Query batch progress at any time.
  - Endpoint: `GET /api/v1/projects/{project_id}/valuations/{valuation_stage}/batch-status`.
  - Output includes: `status`, `total_employees`, `expected_employees`, `total_batches`, `progress_percentage`, timestamps.
- **FR-VAL-3 (Valuation Status)**: Get high-level valuation status for a stage.
  - Endpoint: `GET /api/v1/projects/{project_id}/valuations/{valuation_stage}/status`.
- **FR-VAL-4 (Results Retrieval)**: Retrieve aggregate and individual valuation results for a project stage.
  - Endpoint(s): `GET /api/v1/projects/{project_id}/valuations/{valuation_stage}/results` and individual results via `employee_valuation_results` store.
- **FR-VAL-5 (Individual Employee Results)**: Retrieve single employee valuation data by `employee_code` with `employee_type` filters.
- **FR-VAL-6 (Task Management)**: List, start, cancel, retry, and bulk operations for valuation tasks.
  - Endpoints include `/api/v1/tasks/`, `/api/v1/tasks/{task_id}`, `/api/v1/tasks/{task_id}/start|cancel|retry`, `/api/v1/tasks/bulk`, `/api/v1/tasks/project/{project_id}`.

### 2.9 Frontend Application Behavior
- **FR-FE-1 (Auth Interceptor)**: Automatically attach bearer tokens to API requests; handle 401 by redirecting to sign-in after trying token refresh.
- **FR-FE-2 (Project Details UI)**: Render a stepper/tabs for project stages and show stage-specific components: `Contract and Planning`, `Last Year Report and Results`, `Data`, `Assumptions`, `Benefits Structure`, `Valuation`, `Report`, `Invoicing`, `Correspondence`, `Completed`.
- **FR-FE-3 (Employee Views)**: Provide grids and detail views for active and pensioner employee data; allow search by code.
- **FR-FE-4 (Valuation Status UI)**: Display batch progress and counts; allow triggering batch runs where permitted.

---

## 3. API Overview (Non-exhaustive)

### 3.1 Core (NestJS)
- Auth: `POST /auth/login`, `POST /auth/refresh-token`, `POST /auth/logout`
- Roles: `POST /roles`, `GET /roles`, `GET /roles/:id`, `PUT /roles/:id`, `DELETE /roles/:id`
- Users: CRUD under `/users` (authenticated; permissioned)
- Companies: `POST /companies` (manage), `GET /companies` (read), `GET /companies/:id`, `PUT /companies/:id` (manage), `DELETE /companies/:id`
- Employee Data (Active): CRUD under `/active-employee-data`
- Employee Data (Pensioner): CRUD under `/pensioner-employee-data`
- Projects: CRUD under `/projects` and sub-resources for stage payloads

### 3.2 Valuation Service (FastAPI)
- Health/Info: `GET /health`, `GET /db-info`, `GET /env-path`, `GET /env-port`
- Users: `POST /api/v1/users`, `GET /api/v1/users`, `GET /api/v1/users/{user_id}`, `PUT /api/v1/users/{user_id}`, `DELETE /api/v1/users/{user_id}`
- Projects: `POST /api/v1/projects`, `GET /api/v1/projects`, `GET /api/v1/projects/{project_id}`
- Tasks: `POST /api/v1/tasks/`, `GET /api/v1/tasks/`, `GET /api/v1/tasks/{task_id}`, `PUT /api/v1/tasks/{task_id}`, `DELETE /api/v1/tasks/{task_id}`, `POST /api/v1/tasks/{task_id}/start`, `POST /api/v1/tasks/{task_id}/cancel`, `POST /api/v1/tasks/{task_id}/retry`, `POST /api/v1/tasks/bulk`, `GET /api/v1/tasks/summary`, `GET /api/v1/tasks/project/{project_id}/stages/{stage}`
- Employee Data Views: `GET /api/v1/tasks/project/{project_id}/active-employees`, `GET /api/v1/tasks/project/{project_id}/pensioner-employees`, summaries, and by-code lookups
- Valuations: `POST /api/v1/projects/{project_id}/valuations/{valuation_stage}/run-batch`, `GET /api/v1/projects/{project_id}/valuations/{valuation_stage}/batch-status`, `GET /api/v1/projects/{project_id}/valuations/{valuation_stage}/status`, `GET /api/v1/projects/{project_id}/valuations/{valuation_stage}/results`

---

## 4. Data Model (Key Entities)

### 4.1 User
- `name: string`
- `email: string` (unique)
- `password?: string`
- `verified: boolean`
- `role: ObjectId (Role)`
- `verificationKey?: string`

### 4.2 Role
- `name: string` (unique)
- `permissions: string[]`

### 4.3 UserToken
- `user: ObjectId (User)`
- `token: string` (unique)
- `expiresAt: Date`

### 4.4 Company
- `name: string`
- `code: string` (unique)
- `contactPersons: ContactPerson[]`

### 4.5 Project
- `name: string`
- `valuationDate: Date`
- `valuationType: string`
- `stage: string` (one of project stages)
- `company: string` (ref to Company id)
- `contactPerson: { name, email?, phoneNo }`
- `contract: mixed`
- `lastYearInfo: mixed`
- `requestedDataFiles: mixed`
- `receivedDataFiles: mixed`
- `compiledDataFiles: mixed`
- `assumptions: mixed`
- `benifitsStructure: mixed`
- `valuations: mixed`

### 4.6 ActiveEmployeeData
- `SNO: number`
- `ECODE: string`
- `NAME: string`
- `PAY_SCALE: string`
- `DOA: Date`
- `DOB: Date`
- `PAY: number`
- `AGE: number`
- `PS: string`
- `ORDERLY_ALLOWANCE: number (default 0)`
- `project?: ObjectId (Project)`
- `projectStage?: string`

### 4.7 PensionerEmployeeData
- `SNO: number`
- `ECODE: number`
- `NAME: string`
- `TYPE_OF_PENSIONER: string`
- `DOB: Date`
- `DOR: Date`
- `PENSION_AMOUNT: number`
- `MEDICAL_ALLOWANCE: number (default 0)`
- `ORDERLY_ALLOWANCE: number (default 0)`
- `AGE_AT_RETIREMENT: number`
- `AGE: number`
- `YEARS_TO_RESTORATION: number`
- `CURRENT_VALUE_OF_RESTORED_AMOUNT: number`
- `project?: ObjectId (Project)`
- `projectStage?: string`

---

## 5. Non-Functional Requirements

### 5.1 Security
- **NFR-SEC-1**: All protected endpoints require JWT bearer tokens.
- **NFR-SEC-2**: RBAC enforced at the endpoint level via permission guard.
- **NFR-SEC-3**: Input validation with Joi and schema validators; reject invalid payloads with appropriate HTTP errors.
- **NFR-SEC-4**: Secrets stored in environment variables; do not hardcode secrets in configuration files.

### 5.2 Performance and Scalability
- **NFR-PERF-1**: Batch valuation supports `batch_size` and `max_concurrent_batches`; system should process large datasets in parallel without blocking request threads.
- **NFR-PERF-2**: Progress endpoints must respond within 1s for 95th percentile under typical load (given adequate indexes).
- **NFR-PERF-3**: Pagination for list endpoints (users, projects, tasks, employees) where applicable.

### 5.3 Availability and Reliability
- **NFR-AVAIL-1**: Services should tolerate valuation service downtime; backend should degrade gracefully (e.g., fallback queries or helpful errors).
- **NFR-AVAIL-2**: Background jobs are idempotent where possible; retries won’t corrupt data.

### 5.4 Observability
- **NFR-OBS-1**: Log authentication failures, permission denials, and valuation job lifecycle events.
- **NFR-OBS-2**: Capture key metrics: tasks created/running/failed/completed, employees processed, batch counts.

### 5.5 Usability
- **NFR-UX-1**: Clear stage-based navigation and status indicators for valuations.
- **NFR-UX-2**: Input forms provide inline validation and descriptive error messages.

### 5.6 Portability
- **NFR-PORT-1**: Backend and valuation services containerized and configurable via environment variables.

---

## 6. Constraints, Dependencies, and Configuration
- MongoDB as the persistence layer for both backend and valuation service.
- Required configuration includes `JWT_SECRET`, MongoDB URI, and service base URLs.
- Network access required between backend and FastAPI service.

---

## 7. Acceptance Criteria (Selected End-to-End)
- **AC-1 Login**: Verified user logs in via `/auth/login` → receives `accessToken`; invalid credentials return 401; unverified returns 401 with `Unverified User`.
- **AC-2 Company Permissions**: User without `read_companies` receives 403 on `GET /companies`; with permission, receives 200 and list.
- **AC-3 Create Company**: `POST /companies` with valid payload returns 201 and created entity; invalid payload returns 400 with Joi validation errors.
- **AC-4 Project Stage UI**: Changing project `stage` updates the Angular view to correct stage component.
- **AC-5 Employee Lookup**: Given a project, calling active employee by code returns the correct record or 404.
- **AC-6 Run Valuation**: Trigger run-batch; status endpoint shows `in_progress` with increasing `total_employees` until `completed` with `progress_percentage = 100`.
- **AC-7 Batch Status Fallback**: If no individual results found, status returns `not_started` with message indicating readiness.

---

## 8. Risks and Open Items
- Final list of permission strings beyond examples (e.g., `manage_projects`, `run_valuations`) to be confirmed with stakeholders.
- Exact project sub-resource APIs (assumptions, benefits, files) to be finalized.
- Data import standard formats (CSV/Excel) and validation rules to be documented.

---

## 9. Appendix — Project Stages (from UI)
`Contract and Planning`, `Last Year Report and Results`, `Data`, `Assumptions`, `Benefits Structure`, `Valuation`, `Report`, `Invoicing`, `Correspondence`, `Completed`.


