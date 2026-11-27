# Graph Report - sib  (2026-11-27)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1740 nodes · 2409 edges · 89 communities (77 shown, 12 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 128 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Data Models
- Core App Services
- Invoice Editor UI
- Jalali Date Utilities
- Cryptography and Buffers
- Excel Export Utility
- Report Grid UI
- Date Formatting
- API Constants
- Invoice Calculations
- Item Management UI
- Common UI Components
- Project Dependencies
- App Configuration
- Club Management Page
- SMS Service
- Jalali Date Picker
- PHP Auth Backend
- Database Client
- Dashboard Analytics
- SQL Queries
- Report Models
- App Navigation Shell
- Backup Metadata
- Database Schema
- Payment Dialogs
- Invoice List View
- Party Detail View
- Auth Pages
- Backup Service
- Invoice Actions
- Party Invoice List
- API Response Models
- PHP Core Utilities
- PHP Database Layer
- Party Form UI
- Dialog State Management
- Settings Page
- UI Design System
- PHP SMS Gateways
- Customer Management Page
- Input Formatters
- Chart Visualization
- Win32 Window Management
- App Lifecycle Controller
- Dashboard Page
- Business Profile Settings
- Items Repository
- Account Dialog
- Auth Service Client
- App State Scope
- Backup Management UI
- Windows Native Entry
- Native Geometry Types
- Flutter Windows Host
- Search Picker Widget
- SQL Test Suite
- Secure Storage
- Preferences Store
- Invoices Repository
- Parties Repository
- HTTP Client
- Windows C++ Runner
- Payments Repository
- Main App Entry
- Time Period Utilities
- Flutter Window Controller
- Windows Message Handling
- Win32 Window Proc
- Settings Repository
- Device Identity
- Logo Processing Service
- Windows Plugin Registry
- Report Table Widget
- SMS Repository
- Logging System
- Backend Documentation
- Build Configuration
- Linter Rules
- Exception Classes
- Server Installation Script
- Version Constants
- Invoice Editor State
- Reports Page State
- Accounting Logic

## God Nodes (most connected - your core abstractions)
1. `Win32Window` - 27 edges
2. `q()` - 20 edges
3. `auth_page()` - 17 edges
4. `setting()` - 17 edges
5. `now()` - 15 edges
6. `cfg()` - 15 edges
7. `pay_start()` - 14 edges
8. `dependencies` - 14 edges
9. `FlutterWindow` - 12 edges
10. `e()` - 12 edges

## Surprising Connections (you probably didn't know these)
- `{closure#1}()` --calls--> `e()`  [INFERRED]
  sib-backend/public/install.php → sib-backend/app/core.php
- `{closure#2}()` --calls--> `val()`  [INFERRED]
  sib-backend/public/admin.php → sib-backend/app/core.php
- `FlutterWindow::OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/flutter/generated_plugin_registrant.cc
- `{closure#4}()` --calls--> `csrf_field()`  [INFERRED]
  sib-backend/public/admin.php → sib-backend/app/core.php
- `bad()` --calls--> `e()`  [INFERRED]
  sib-backend/public/admin.php → sib-backend/app/core.php

## Import Cycles
- None detected.

## Communities (89 total, 12 thin omitted)

### Community 0 - "Data Models"
Cohesion: 0.03
Nodes (60): amount, balance, batchId, Category, categoryId, categoryName, code, costUnit (+52 more)

### Community 1 - "Core App Services"
Cohesion: 0.04
Nodes (46): api, appInfo, _applyAuth, AppPhase, AppServices, auth, autoBackup, backupDir (+38 more)

### Community 2 - "Invoice Editor UI"
Cohesion: 0.04
Nodes (47): _addItemLine, _bottomBar, build, createState, _date, _desc, discount, discountValue (+39 more)

### Community 3 - "Jalali Date Utilities"
Cohesion: 0.04
Nodes (48): addMonths, back, d, day, days, from, fromDate, fromIso (+40 more)

### Community 4 - "Cryptography and Buffers"
Cohesion: 0.04
Nodes (44): b, buildXlsx, c, cd, central, chars, cleaned, colLetter (+36 more)

### Community 5 - "Excel Export Utility"
Cohesion: 0.05
Nodes (39): build, busy, _content, createState, credit, customers, _Def, _defs (+31 more)

### Community 6 - "Report Grid UI"
Cohesion: 0.05
Nodes (37): a, _arDigits, b, d, dt, enDigits, _faDigits, fmtJalali (+29 more)

### Community 7 - "Date Formatting"
Cohesion: 0.05
Nodes (34): discount, itemId, kMaxPrice, kMaxQty, lineGross, LineInput, lineTotal, null (+26 more)

### Community 8 - "API Constants"
Cohesion: 0.05
Nodes (36): Item, _active, _add, build, _buy, _categoryId, _cats, _code (+28 more)

### Community 9 - "Invoice Calculations"
Cohesion: 0.06
Nodes (26): bd, bitLen, buf, h, k, m, map, padLen (+18 more)

### Community 10 - "Item Management UI"
Cohesion: 0.06
Nodes (29): actions, build, child, color, confirmDialog, confirmLabel, cs, danger (+21 more)

### Community 11 - "Common UI Components"
Cohesion: 0.06
Nodes (34): dependencies, cupertino_icons, file_picker, flutter, flutter_localizations, flutter_secure_storage, http, logger (+26 more)

### Community 12 - "Project Dependencies"
Cohesion: 0.06
Nodes (30): build, _c, _cell, _chip, _chooseYear, clearable, createState, current (+22 more)

### Community 13 - "App Configuration"
Cohesion: 0.06
Nodes (25): allowInsecureHttp, apiBaseUrl, AppConfig, connectTimeoutSeconds, endpoint, environment, isDev, receiveTimeoutSeconds (+17 more)

### Community 14 - "Club Management Page"
Cohesion: 0.07
Nodes (28): batchId, consent, db, errors, failed, _fatal, label, maxLength (+20 more)

### Community 15 - "SMS Service"
Cohesion: 0.10
Nodes (20): csrf_field(), csrf_token(), e(), redir(), clean_full_name(), user_by_phone(), user_display_name(), bad() (+12 more)

### Community 16 - "Jalali Date Picker"
Cohesion: 0.07
Nodes (26): build, busy, _compose, createState, customers, debtorsOnly, dispose, done (+18 more)

### Community 17 - "PHP Auth Backend"
Cohesion: 0.07
Nodes (25): checkpoint, close, _closed, _configure, _db, DbRow, _depth, exec (+17 more)

### Community 18 - "Database Client"
Cohesion: 0.07
Nodes (26): chart, customers, customersDebt, dashboard, db, expenses, _i, itemSales (+18 more)

### Community 19 - "Dashboard Analytics"
Cohesion: 0.07
Nodes (22): invoice_id, item_id, p, qCashByDay, qExpenseBreakdown, qExpenseDetails, qExpensesByDay, qGoodsPurchasesByDay (+14 more)

### Community 20 - "SQL Queries"
Cohesion: 0.07
Nodes (27): boldRows, cashIn, cashOut, chart, ChartSeries, cogs, ColType, columns (+19 more)

### Community 21 - "Report Models"
Cohesion: 0.07
Nodes (26): ApiErrorCodes, ApiHeaders, ApiPaths, authorization, badCode, badPhone, bearer, blocked (+18 more)

### Community 22 - "App Navigation Shell"
Cohesion: 0.07
Nodes (26): app, appVersion, counts, createdAt, db, dbSha256, dbSize, formatVersion (+18 more)

### Community 23 - "Backup Metadata"
Cohesion: 0.08
Nodes (15): action, build, color, createState, extended, icon, index, label (+7 more)

### Community 24 - "Database Schema"
Cohesion: 0.08
Nodes (19): categories, invoice_items, invoices, items, kDefaultSettings, kind, kMigrations, kSchemaV1 (+11 more)

### Community 25 - "Payment Dialogs"
Cohesion: 0.08
Nodes (22): _amount, bool, build, createState, _date, _desc, dispose, false (+14 more)

### Community 26 - "Invoice List View"
Cohesion: 0.08
Nodes (22): DateRange, build, createState, _delete, dispose, initialKind, initState, InvoicesPage (+14 more)

### Community 27 - "Party Detail View"
Cohesion: 0.08
Nodes (21): _allocate, balances, balancesView, balKind, build, createState, _delete, direction (+13 more)

### Community 28 - "Auth Pages"
Cohesion: 0.08
Nodes (21): build, _busy, _CenterCard, child, _code, _codeStep, createState, dispose (+13 more)

### Community 29 - "Backup Service"
Cohesion: 0.09
Nodes (18): BackupMeta, BackupFileEntry, backupFileName, BackupInfo, BackupService, _counts, create, inspect (+10 more)

### Community 30 - "Invoice Actions"
Cohesion: 0.09
Nodes (20): InvoiceDetail, _addPayment, build, changed, createState, d, _delete, _deletePayment (+12 more)

### Community 31 - "Party Invoice List"
Cohesion: 0.09
Nodes (20): build, changed, createState, false, initState, _invoiceList, invoices, _lineList (+12 more)

### Community 32 - "API Response Models"
Cohesion: 0.09
Nodes (22): app, AppInfo, AuthResult, body, code, daysLeft, downloadUrl, endsAt (+14 more)

### Community 33 - "PHP Core Utilities"
Cohesion: 0.10
Nodes (19): _address, build, _card, checking, createState, dispose, _footer, initState (+11 more)

### Community 34 - "PHP Database Layer"
Cohesion: 0.15
Nodes (17): base_path(), en_to_fa(), enc(), fa_to_en(), g2j(), is_https(), jdate(), money() (+9 more)

### Community 35 - "Party Form UI"
Cohesion: 0.22
Nodes (19): add_days(), client_ip(), db(), insert_id(), migrate_if_needed(), now(), q(), quota_take() (+11 more)

### Community 36 - "Dialog State Management"
Cohesion: 0.11
Nodes (18): Party, _active, build, _code, _consent, createState, _desc, dispose (+10 more)

### Community 37 - "Settings Page"
Cohesion: 0.10
Nodes (19): AppCard, AppDialog, DropdownField, EmptyState, PageHeader, SectionTitle, StatCard, StatusChip (+11 more)

### Community 38 - "UI Design System"
Cohesion: 0.27
Nodes (17): app_log(), cfg(), dec(), http_post_json(), setting(), gateway_active(), gateways_enabled(), ippanel_send() (+9 more)

### Community 39 - "PHP SMS Gateways"
Cohesion: 0.12
Nodes (13): build, createState, CustomersPage, _CustomersPageState, _delete, dispose, initState, kind (+5 more)

### Community 40 - "Customer Management Page"
Cohesion: 0.12
Nodes (13): build, controller, enabled, formatEditUpdate, label, MoneyField, MoneyInputFormatter, moneyOf (+5 more)

### Community 41 - "Input Formatters"
Cohesion: 0.16
Nodes (16): _SearchPicker, _SearchPickerState, LoginPage, _LoginPageState, ClubPage, _ClubPageState, _QuickSms, _QuickSmsState (+8 more)

### Community 42 - "Chart Visualization"
Cohesion: 0.12
Nodes (13): _AccountDialog, _AccountDialogState, avatarInitial, build, checking, createState, _logout, _refresh (+5 more)

### Community 43 - "Win32 Window Management"
Cohesion: 0.12
Nodes (14): BarChartView, _BarPainter, build, colors, data, fontFamily, gridColor, height (+6 more)

### Community 44 - "App Lifecycle Controller"
Cohesion: 0.13
Nodes (6): Win32Window::GetClientArea(), Win32Window::Show(), EnableNonClientDpiScaling, WindowClassRegistrar, class_registered_, instance_

### Community 45 - "Dashboard Page"
Cohesion: 0.13
Nodes (10): DashboardData, build, createState, d, DashboardPage, _DashboardPageState, initState, _load (+2 more)

### Community 46 - "Business Profile Settings"
Cohesion: 0.13
Nodes (14): BackupPage, _BackupPageState, build, busy, _chooseFolder, _create, createState, files (+6 more)

### Community 47 - "Items Repository"
Cohesion: 0.12
Nodes (12): BusinessProfile, decodeLogo, displayName, empty, encodeLogo, fromSettings, hasLogo, logo (+4 more)

### Community 48 - "Account Dialog"
Cohesion: 0.12
Nodes (15): addCategory, adjustStock, categories, create, db, delete, deleteCategory, ItemsRepo (+7 more)

### Community 49 - "Auth Service Client"
Cohesion: 0.13
Nodes (11): api, AuthService, check, logout, OtpTicket, requestOtp, resendAfterSeconds, sendSms (+3 more)

### Community 50 - "App State Scope"
Cohesion: 0.13
Nodes (9): _CloseHandler, controller, ensureInitialized, init, main, onWindowClose, options, setPreventClose (+1 more)

### Community 51 - "Backup Management UI"
Cohesion: 0.18
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 52 - "Windows Native Entry"
Cohesion: 0.14
Nodes (8): Scale(), Point, x, y, Size, height, width, Win32Window::Win32Window()

### Community 53 - "Native Geometry Types"
Cohesion: 0.19
Nodes (7): FlutterWindow::OnCreate(), Win32Window::Destroy(), Win32Window::OnCreate(), Win32Window, child_content_, quit_on_close_, window_handle_

### Community 54 - "Flutter Windows Host"
Cohesion: 0.15
Nodes (6): app, AppContext, AppScope, of, read, svc

### Community 55 - "Search Picker Widget"
Cohesion: 0.15
Nodes (5): AccountingApp, build, AppController, controller, _Gate

### Community 56 - "SQL Test Suite"
Cohesion: 0.15
Nodes (10): AppPaths, autoBackupDir, dataDir, dbPath, defaultBackupDir, init, logsDir, prefsPath (+2 more)

### Community 57 - "Secure Storage"
Cohesion: 0.17
Nodes (4): ApiClient, _client, close, post

### Community 58 - "Preferences Store"
Cohesion: 0.17
Nodes (9): getBool, getString, load, _m, path, PrefsStore, _save, setBool (+1 more)

### Community 59 - "Invoices Repository"
Cohesion: 0.17
Nodes (9): _assertStockOk, db, delete, InvoicesRepo, list, nextNumber, _qInvoiceById, save (+1 more)

### Community 60 - "Parties Repository"
Cohesion: 0.17
Nodes (11): count, create, db, delete, linesOf, list, nextCode, PartiesRepo (+3 more)

### Community 61 - "HTTP Client"
Cohesion: 0.17
Nodes (9): FileService, _firstPath, openPath, openUrl, pickBackupFile, pickDirectory, pickImage, saveBytes (+1 more)

### Community 62 - "Windows C++ Runner"
Cohesion: 0.17
Nodes (9): clearToken, _kPhone, _kToken, _read, readPhone, readToken, _s, saveSession (+1 more)

### Community 63 - "Payments Repository"
Cohesion: 0.18
Nodes (6): build, createLabel, createState, items, q, title

### Community 65 - "Main App Entry"
Cohesion: 0.18
Nodes (9): add, allocate, db, delete, listDetailed, of, openInvoicesOf, PaymentsRepo (+1 more)

### Community 66 - "Time Period Utilities"
Cohesion: 0.33
Nodes (9): sub_public(), app_info(), auth_or_fail(), {closure#1}(), device_id_of(), fail(), in_str(), inactive_error() (+1 more)

### Community 67 - "Flutter Window Controller"
Cohesion: 0.20
Nodes (7): Granularity, granularityLabel, j, key, label, PeriodKey, periodOf

### Community 68 - "Windows Message Handling"
Cohesion: 0.20
Nodes (5): FlutterWindow::OnDestroy(), FlutterWindow, flutter_controller_, project_, Win32Window::OnDestroy()

### Community 71 - "Device Identity"
Cohesion: 0.22
Nodes (7): AppDatabase, allowNegativeStock, db, getBool, setBool, SettingsRepo, updateCostOnPurchase

### Community 72 - "Logo Processing Service"
Cohesion: 0.22
Nodes (4): DeviceIdentity, _fallbackGuid, _id, name

### Community 73 - "Windows Plugin Registry"
Cohesion: 0.22
Nodes (4): LogoService, maxSide, maxSourceBytes, prepare

### Community 75 - "SMS Repository"
Cohesion: 0.22
Nodes (6): build, _colWidth, _numeric, ReportGrid, table, ReportTable

### Community 76 - "Logging System"
Cohesion: 0.22
Nodes (6): db, failedCount, failedPartyIds, history, log, SmsRepo

### Community 77 - "Backend Documentation"
Cohesion: 0.25
Nodes (5): error, info, Log, prune, _write

### Community 78 - "Build Configuration"
Cohesion: 0.50
Nodes (3): include, linter, rules

### Community 79 - "Linter Rules"
Cohesion: 0.50
Nodes (3): BackupFormatException, DomainError, ApiException

### Community 82 - "Version Constants"
Cohesion: 0.67
Nodes (3): Windows CMake Configuration, Flutter CMake Configuration, Runner CMake Configuration

## Knowledge Gaps
- **1142 isolated node(s):** `amount`, `balance`, `batchId`, `Category`, `categoryId` (+1137 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1324 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Native Geometry Types` to `PHP API Router`, `Windows Message Handling`, `Settings Repository`, `App Lifecycle Controller`, `Windows Native Entry`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **What connects `amount`, `balance`, `batchId` to the rest of the system?**
  _1142 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.03225806451612903 - nodes in this community are weakly interconnected._
- **Why does `FlutterWindow` connect `Windows Message Handling` to `PHP API Router`, `Win32 Window Proc`, `Native Geometry Types`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Should `Core App Services` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Why does `DateRange` connect `Invoice List View` to `Party Detail View`, `Jalali Date Utilities`, `Project Dependencies`, `Excel Export Utility`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Should `Invoice Editor UI` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._