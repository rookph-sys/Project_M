# Project Marbles — PvE Implementation Specification v0.3 (Godot)

**Status:** Implementation Baseline
**مبنا:** v0.2 (Unity) — تبدیل‌شده به Godot + اصلاح باگ‌های عددی و منطقی
**Scope:** فقط PvE
**PvP / Online:** فعلاً توسعه داده نمی‌شود؛ Architecture از ابتدا با Host-Authoritative Multiplayer آینده سازگار است.

> تمام تغییرات نسبت به v0.2 و دلیلشان در [REVIEW-v0.2.md](REVIEW-v0.2.md) آمده.
> بلوک‌های ⚠ **DECISION** تصمیم‌هایی هستند که من نمی‌توانستم جای شما بگیرم و Phase 1 را بلاک می‌کنند.

---

## 1. تصمیم‌های قفل‌شده‌ی Production

| | |
|---|---|
| **Engine** | Godot 4.x — نسخه‌ی دقیق باید Pin شود (آخرین Stable در زمان شروع) و در `project.godot` ثبت شود |
| **Renderer** | Forward+ |
| **Physics** | **Jolt Physics** (نه Godot Physics) — در `physics/3d/physics_engine` انتخاب می‌شود |
| **Language** | C# (.NET build of Godot) |
| **Target** | Windows 10/11 x64 — Steam |
| **UI Reference** | 1920×1080 / 16:9، `canvas_items` stretch mode، `expand` aspect |

بازی باید در Aspect Ratioهای دیگر Scale شود ولی طراحی اولیه بر اساس 16:9 است.

**چرا Jolt:** پایداری بهتر در برخورد کره‌ها، Sleep منطقی‌تر، و Reproducibility بهتر روی یک Build. Godot Physics در خوشه‌های کره‌ی نزدیک‌به‌هم Jitter بیشتری دارد.

**چرا C#:** ارزیابی Candidate Shotهای AI (§60) محاسبات سنگینی است که در GDScript گران تمام می‌شود.

---

## 2. Godot Project Settings — مقادیر اجباری

این‌ها Baseline فیزیک را تعیین می‌کنند و نباید بدون تست عوض شوند:

```ini
physics/common/physics_ticks_per_second   = 120
physics/common/max_physics_steps_per_frame = 16
physics/common/physics_jitter_fix          = 0.0

physics/3d/physics_engine        = "Jolt Physics"
physics/3d/default_gravity       = 9.81
physics/3d/default_gravity_vector = (0, -1, 0)
physics/3d/default_linear_damp   = 0.0
physics/3d/default_angular_damp  = 0.0

physics/3d/sleep_threshold_linear  = 0.0
physics/3d/sleep_threshold_angular = 0.0
physics/3d/time_before_sleep       = 1000.0
```

### دو نکته‌ی حیاتی مخصوص Godot

**۱. `linear_damp_mode` و `angular_damp_mode` هر RigidBody3D باید روی `REPLACE` باشد.**
حالت پیش‌فرض `COMBINE` است و مقدار Damping پیش‌فرض دنیا/Area را **به** مقدار بدنه **اضافه** می‌کند. اگر این را نبینید، تمام Travel Distanceهای §23 اشتباه از آب درمی‌آیند و ساعت‌ها دنبال دلیلش می‌گردید. Default دنیا را هم بالا روی صفر گذاشته‌ایم تا دو لایه محافظت داشته باشیم.

**۲. Sleep خودکار موتور غیرفعال است.** Settle را خودمان تشخیص می‌دهیم (§30). به `RigidBody3D.sleeping` تکیه نمی‌کنیم چون آستانه‌هایش قابل اتکا و قابل تنظیم نیستند.

---

## 3. Localization

Vertical Slice: **English Only**

تمام Textها از روز اول با Localization Key ذخیره شوند. هیچ String مستقیم در UI نباشد. Godot خودش `tr()` و فایل CSV/PO دارد.

```text
marble.standard.name
marble.standard.description
objective.ringer.knockout
objective.holes.sink
ui.turn
ui.power
ui.retry
```

فارسی و RTL در Scope نسخه Vertical Slice نیست. دلیل: RTL فقط Translation نیست — روی Text Shaping، Layout، Alignment، جهت Icon و UI Testing هزینه ایجاد می‌کند. بعداً قابل اضافه شدن است.

---

## 4. Production Assumption

- 1 Godot Gameplay Programmer — Full Time
- 1 Game Designer / Generalist — Full Time
- Art — Part Time / Outsourced
- Audio — Part Time / Licensed

Timeline تیم تک‌نفره در §82.

---

## 5. Art Pipeline

**Prototype:** Primitive Mesh، Material ساده، UI و Audio جایگزین.
تا Core Physics تأیید نشده، Asset Production جدی شروع نمی‌شود.

**Vertical Slice:** Marble Material اختصاصی، Arena اختصاصی، UI اختصاصی، VFX اختصاصی، Audio لایسنس‌دار یا اختصاصی.

Assetی که License آن مشخص نیست وارد Shipping Build نمی‌شود.

---

## 6. World Scale

```text
1 Godot Unit = 1 Meter
```

این Scale عمداً اندازه‌ی واقعی تیله نیست. تیله‌ی واقعی خیلی کوچک‌تر است، ولی Scale بسیار کوچک Physics Tuning را سخت، Collision را حساس، و Camera و VFX را پیچیده می‌کند.

---

## 7. Coordinate System

```text
X = Horizontal
Y = Vertical / Gravity   (Godot هم Y-up است)
Z = Forward / Backward
```

Gameplay روی Plane **XZ** انجام می‌شود. Gravity: `(0, -9.81, 0)`.

---

## 8. Base Arena

```text
Width (X) = 7.20 m     →   -3.60 … +3.60
Depth (Z) = 4.80 m     →   -2.40 … +2.40
Floor     = Y 0
Marble center at rest = Y 0.10
```

---

## 9. ⚠ DECISION — Arena Walls

**این تنها تصمیمی است که Phase 1 را واقعاً بلاک می‌کند.**

v0.2 در دو جا با خودش تناقض دارد:
- §21 یک «Arena Wall Material» با `bounce = 1.00` تعریف می‌کند، و §49 Bank Shot را بر اساس برخورد با «Arena Wall» تعریف می‌کند → یعنی Arena دیوار دارد.
- §37 و کل Knockout (§44) بر پایه‌ی این هستند که Marble از Arena **بیرون بیفتد** → یعنی Arena دیوار ندارد.

اگر دیوار دور تا دور باشد هیچ‌چیز بیرون نمی‌افتد و Knockout غیرممکن است. اگر نباشد، Bank Shot و کل هویت Rubber Marble جایی برای برخورد ندارد.

**پیشنهاد من — گزینه A (در این سند فرض شده):**

> Arena **میز باز** است، بدون دیوار پیرامونی. Marble از لبه می‌افتد.
> **Bank Surface** فقط Objectهای داخل زمین هستند: Obstacle Wallها و Bumperها که Level تعریف می‌کند.
> §22 به «Bank Surface Material» تغییر نام می‌دهد.

این گزینه Ringer، Holes و Knockout را هم‌زمان کار می‌اندازد.

**عارضه‌ی جانبی که باید بپذیرید:** Rubber Marble فقط در Levelهایی معنی دارد که Bank Surface دارند — در چیدمان فعلی یعنی Level 06 و Level 10، و در ۸ Level دیگر عملاً یک Standard ضعیف است. اگر Rubber باید در کل بازی مفید باشد، باید در Levelهای بیشتری Bumper بگذارید. (جزئیات در REVIEW، مورد P1-5.)

**گزینه B:** دیوار پیرامونی کوتاه فقط روی دو ضلع بلند (X = ±3.60)، و دو ضلع کوتاه (Z = ±2.40) باز. آن‌وقت Bank Shot کار می‌کند و Knockout هم از دو سر باز ممکن است. پیچیده‌تر ولی Rubber را در همه‌ی Levelها زنده نگه می‌دارد.

تا تأیید شما، **گزینه A** مبنای بقیه‌ی سند است.

---

## 10. Marble Size

```text
Radius   = 0.10 m
Diameter = 0.20 m
```

تمام Marbleهای Gameplay یک اندازه دارند. Hitbox یکسان Balance را ساده می‌کند. Material و Effect می‌تواند فرق کند، Collider نه.

---

## 11. Ring

```text
Center = (0, 0)
Radius = 1.45 m
```

هیچ Collider ندارد. فقط Logical Boundary است (یک Decal یا Mesh تخت روی زمین).

---

## 12. Launch Zone

**Player:**
```text
X = -2.80 … +2.80
Z = -2.05 … -1.65      (Width 5.60, Depth 0.40)
```

**AI (Knockout):**
```text
X = -2.80 … +2.80
Z = +1.65 … +2.05
```

فاصله‌ی لبه‌ی داخلی Launch Zone تا لبه‌ی Ring: `1.65 - 1.45 = 0.20 m`.

---

## 13. Placement Collision Rule

Marble هنگام Placement نباید با هیچ Collider ـی Overlap داشته باشد.

```text
Minimum center-to-center = 0.21 m      (2 × Radius + 0.01)
```

Placement نامعتبر → Marble قرمز، Confirm غیرفعال.

---

## 14. Launch Zone Blocked Rule

Marbleهای قبلی داخل Arena می‌مانند و می‌توانند Launch Zone را Block کنند. این بخشی از Board State است. با عرض 5.6 متر، هشت Marble نمی‌توانند آن را به شکل عادی کامل مسدود کنند.

**اصلاح نسبت به v0.2:** v0.2 می‌گفت Zone به سمت **داخل** Arena گسترش پیدا کند. این باگ است: `-1.65 + 0.25 = -1.40` که از لبه‌ی Ring (`-1.45`) رد می‌شود و بازیکن می‌تواند Marble را **داخل Ring** بگذارد.

گسترش به سمت **عقب** انجام می‌شود:

```text
Expansion 1:  Z_min  -2.05 → -2.20
Expansion 2:  Z_min  -2.20 → -2.30     (Emergency)
```

`-2.30` سقف مطلق است: لبه‌ی Arena در `-2.40` و شعاع Marble `0.10` است.

Emergency در Telemetry ثبت می‌شود: `LaunchZoneEmergencyUsed`.
اگر در Playtest معمولاً اتفاق بیفتد، Stage Design مشکل دارد.

---

## 15. Shot Power

```text
Input Power  = 0.0 … 1.0
MinimumPower = 0.12
```

بازیکن نمی‌تواند Shot تقریباً صفر بزند.

---

## 16. Base Shot Impulse

```text
BaseShotImpulse = 5.20 N·s

FinalImpulse = BaseShotImpulse × InputPower × MarbleShotMultiplier
```

در Godot:

```csharp
marble.ApplyCentralImpulse(direction * finalImpulse);
```

Impulse فقط روی XZ اعمال می‌شود. هیچ Vertical Impulse داده نمی‌شود.

### Spin-up — اصلاح نسبت به v0.2

Impulse خالص در مرکز جرم، Marble را با سرعت خطی و **سرعت زاویه‌ای صفر** رها می‌کند. یعنی Marble اول می‌**لغزد**، بعد Friction آن را به Rolling می‌رساند و در این فاز انرژی زیادی از دست می‌دهد. نتیجه: Travel Distance به Friction وابسته می‌شود و رابطه‌ی Power→Distance **غیرخطی** می‌شود — دقیقاً برعکس آن چیزی که §23 می‌خواهد.

برای همین، هم‌زمان با Impulse، سرعت زاویه‌ای متناظر با Rolling بدون لغزش داده می‌شود:

```csharp
// v = ω × r   →   ω = v / r، حول محور عمود بر جهت حرکت
Vector3 v = direction * (finalImpulse / marble.Mass);
marble.AngularVelocity = new Vector3(0, 1, 0).Cross(v) / Radius;
```

این کار:
- فاز لغزش را حذف می‌کند
- Travel Distance را عمدتاً تابع Damping می‌کند (قابل پیش‌بینی و خطی)
- دقت Prediction مربوط به AI را بالا می‌برد

---

## 17. Physics Simulation

Godot برخلاف Unity از ابتدا Tick ثابت دارد؛ نیازی به `SimulationMode.Script` نیست.

```text
physics_ticks_per_second = 120     →  step = 0.008333333 s
```

تمام Gameplay Logic مربوط به حرکت در `_PhysicsProcess` اجرا می‌شود. هیچ‌وقت `_Process` یا Render Delta وارد محاسبات فیزیک نمی‌شود.

`max_physics_steps_per_frame = 16` جلوی Spiral of Death را در فریم‌های کند می‌گیرد.
`physics_jitter_fix = 0` چون Smoothing آن با Reproducibility (§71 Test D) تداخل دارد.

---

## 18. Determinism

این پروژه ادعای **Cross-Machine Deterministic Physics** ندارد.

هدف: **Reproducible-enough simulation on the same build and platform.**

بنابراین Multiplayer آینده **Host Authoritative** است، نه Deterministic Lockstep. Clientها نتیجه‌ی Physics میزبان را می‌پذیرند.

---

## 19. ⚠ RISK — AI Prediction در Godot

**این مهم‌ترین ریسک فنی تبدیل به Godot است و باید در هفته‌ی اول Spike شود.**

کل طراحی AI (§60) فرض می‌کند می‌شود ده‌ها Candidate Shot را در یک Physics Scene جدا **سریع‌تر از زمان واقعی** شبیه‌سازی کرد. در Unity این کار با `Physics.Simulate(scene)` ساده است. **Godot معادل تمیزی برای Step کردن دستی یک Space ندارد** — `physics_ticks_per_second` سراسری است و World3D دوم را نمی‌شود مستقل جلو برد.

### پیشنهاد — Simulator اختصاصی ۲بعدی (گزینه‌ی توصیه‌شده)

Arena تخت است، همه‌ی Marbleها شعاع یکسان دارند، و Gravity روی حرکت افقی اثری ندارد. یعنی یک شبیه‌ساز دیسک دوبعدی کافی است:

- Integration با Damping نمایی
- برخورد دیسک-دیسک کشسان با جرم‌های متفاوت
- برخورد دیسک با Segment (برای Obstacle و Bumper)
- خروج از مرز Arena

حدوداً ۲۰۰ خط C#، چند هزار برابر سریع‌تر از Physics Engine، کاملاً Deterministic، و قابل اجرا روی Thread جدا. علاوه بر AI، برای Aim Preview و Level Validator هم استفاده می‌شود.

**هزینه:** باید با Physics واقعی کالیبره شود. تلورانس §20 معیار قبولی است.

### جایگزین‌ها

- **B:** شبیه‌سازی با سرعت عادی روی چند فریم — AI کند می‌شود، برای 64 Candidate غیرعملی است.
- **C:** یک `PhysicsDirectSpaceState3D` جدا + `PhysicsServer3D` دستی — باید Spike شود که اصلاً ممکن هست یا نه.

تا نتیجه‌ی Spike، **گزینه A** مبنا است.

---

## 20. AI Prediction Accuracy — نتیجه‌ی واقعی اندازه‌گیری

**وضعیت: Spike انجام شد. گزینه A پیاده‌سازی شد (`scripts/sim.gd`).** اعداد زیر خروجی `tools/sim_check.gd` هستند.

### هدف اولیه و چرا عوض شد

v0.2 خواسته بود «۹۵٪ موقعیت‌های پیش‌بینی‌شده داخل ۰.۰۵ متر». این عدد با فرض یک Physics Scene کامل نوشته شده بود. دو چیز در عمل معلوم شد:

**۱. Shot آزاد از این هم دقیق‌تر درآمد.** بعد از Fit کردن ضریب Damping هر تیله روی فیزیک واقعی:

```text
۱۸ اندازه‌گیری، میانگین خطا 0.011 m، بدترین 0.058 m
```

**۲. شکستن خوشه داستان دیگری است.** توافق دقیق روی «چند تیله از Ring بیرون رفت»:

```text
exact   77%
±1 تیله 100%
```

### یک تست که فرض من را رد کرد

فرض طبیعی این است که بقیه‌ی خطا «آشوب» است و هیچ مدلی نمی‌تواند بهتر عمل کند. این را تست کردم: همان Shot را دو بار اجرا کردم با جابه‌جایی **۱ میلی‌متری** شلیک‌کننده.

```text
۲۰ جفت → نتیجه‌ی یکسان در 100% موارد
```

یعنی **آشوب نیست.** این خوشه کاملاً قابل پیش‌بینی است و ۲۳٪ باقی‌مانده ضعف مدل است، نه قانون طبیعت.

علت محتمل: Simulator تماس‌ها را جفت‌به‌جفت و به ترتیب Index حل می‌کند، در حالی که Jolt کل خوشه را هم‌زمان Solve می‌کند — و وقتی تیله‌ها ۲ سانتی‌متر فاصله دارند این فرق می‌کند. درستش کردن یعنی نوشتن یک Solver هم‌زمان.

### چرا فعلاً درست نمی‌شود

چون AI به این دقت نیاز ندارد. AI **رتبه‌بندی** می‌کند، نه گزارش موقعیت. «±۱ تیله ۱۰۰٪» یعنی هیچ‌وقت یک Shot را به‌کلی اشتباه نمی‌خواند. در ضمن هر دو Difficulty که Ship می‌شوند عمداً خطای بسیار بزرگ‌تری تزریق می‌کنند (±۴° و ±۱.۵°).

**اما این یک بدهی ثبت‌شده است،** نه یک ویژگی. اگر AI زمانی حس شد که میز را اشتباه می‌خواند، اولین جایی که باید سراغش رفت همین است.

### ضریب برخورد

Simulator یک ضریب `spin_transfer` دارد که افت انرژی ناشی از به‌چرخش‌افتادن تیله‌ی ضربه‌خورده را مدل می‌کند. تئوری می‌گوید `5/7 = 0.714`؛ Fit روی داده‌ی واقعی `0.55` داد (اصطکاک تماس و ضربه‌های غیرمرکزی). بدون این ضریب Simulator خوش‌بین است و Knock Outهایی پیش‌بینی می‌کند که اتفاق نمی‌افتند.

---

## 21. Physics Solver

Jolt:

```text
velocity_iterations = 10
position_iterations = 2
```

Marble:

```text
continuous_cd = true           (Jolt: motion_quality = Linear Cast)
```

Static Arena: Discrete.

---

## 22. Gravity و Rolling

Gravity: **ON** — `(0, -9.81, 0)`

Marbleها واقعاً روی سطح **Roll** می‌کنند. Translation و Rotation هر دو Physics-Based هستند. Rotation هیچ‌وقت Freeze نمی‌شود.

این بازی Sliding Disc Simulator نیست.

---

## 23. PhysicsMaterial در Godot — تفاوت مهم با Unity

v0.2 برای هر سطح **Static Friction** و **Dynamic Friction** جدا و حالت‌های `Friction Combine` / `Bounce Combine` تعریف کرده بود. **Godot این‌ها را ندارد.**

`PhysicsMaterial` در Godot فقط دارد:

```text
friction   (0..1)
rough      (bool)
bounce     (0..1)
absorbent  (bool)
```

و حالت ترکیب قابل انتخاب نیست.

بنابراین هر جفت Static/Dynamic به **یک عدد** جمع می‌شود. مقدار Dynamic مبنا قرار می‌گیرد، چون حرکت پیوسته چیزی است که اهمیت دارد.

**نکته:** چون فرمول ترکیب Godot/Jolt مستند و قابل انتخاب نیست، مقدار **مؤثر** باید اندازه‌گیری شود نه حدس زده. §23 (Travel Distance) معیار نهایی است.

### Floor

```text
friction = 0.50
bounce   = 0.00
```

### Bank Surface — Obstacle Wall و Bumper

```text
friction = 0.08
bounce   = 1.00
```

مقدار واقعی Bounce از Material خود Marble می‌آید.

---

## 24. Expected Travel Distances — منبع حقیقت

این اعداد از Raw Physics Values **مهم‌تر** هستند. روی Arena خالی، Standard Marble:

| Power | Distance |
|---|---|
| 25% | 1.25 m ±10% |
| 50% | 2.55 m ±10% |
| 100% | 5.05 m ±10% |

اگر Implementation با مقادیر Physics به این رفتار نرسید، **Physics Values عوض می‌شوند، نه این اعداد.**

**توجه به یک پیامد طراحی:** Shot تمام‌قدرت 5.05 متر می‌رود، ولی عمق Arena از Launch Zone (`Z = -1.85`) تا لبه‌ی دور فقط `4.25 m` است. یعنی **Shot مستقیم با قدرت کامل، Marble بازیکن را از میز بیرون می‌اندازد.** این عمدی و خوب است — قدرت کامل باید ریسک داشته باشد — ولی Tutorial باید آن را پوشش دهد و در Knockout (§45) یعنی امتیاز به حریف.

---

## 25. Marble Roster Baseline

**اصلاح عددی نسبت به v0.2.** در v0.2 ستون Linear Damping با Travel Targetهای هر Marble هم‌خوان نبود. با مدل Damping نمایی، مسافت کل برابر است با:

```text
distance = v0 / linear_damp
v0       = (BaseShotImpulse × ShotMult) / Mass
```

مقادیر Damping طوری بازنویسی شده‌اند که از همین فرمول به Target هر Marble برسند:

**این جدول دیگر حدس نیست — اندازه‌گیری‌شده است.** مقادیر زیر خروجی `tools/calibrate.gd` روی Godot 4.7.2 + Jolt هستند و هر شش Marble با آن‌ها دقیقاً روی Travel Target خودشان می‌نشینند (خطای حداکثر ۰.۲٪).

| Marble | Mass | Shot Mult. | v₀ (m/s) | Target @100% | **Linear Damp** | Angular Damp | Friction | **Restitution** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Standard | 1.00 | 1.00 | 5.20 | 5.05 m | **1.129** | 0.45 | 0.40 | **0.82** |
| Heavy | 1.60 | 1.25 | 4.06 | 4.00 m | **1.118** | 0.55 | 0.45 | **0.68** |
| Rubber | 0.90 | 0.95 | 5.49 | 5.80 m | **1.064** | 0.30 | 0.25 | **0.96** |
| Precision | 0.85 | 0.72 | 4.40 | 3.60 m | **1.419** | 0.50 | 0.40 | **0.80** |
| Sticky | 1.10 | 0.90 | 4.25 | 2.80 m | **1.566** | 1.10 | 0.75 | **0.22** |
| Magnet | 1.00 | 0.95 | 4.94 | 4.70 m | **1.168** | 0.50 | 0.40 | **0.80** |

### چرا Damping از حساب کاغذی بیشتر درآمد

فرمول ساده‌ی `distance = v₀ / lin_damp` اشتباه است، چون وقتی کره می‌غلتد، Angular Damping هم از طریق قید غلتش سرعت خطی را می‌خورد. رابطه‌ی درست:

```text
distance = v₀ / ( (5/7) × (lin_damp + 0.4 × ang_damp) )
```

(ضریب ۵/۷ از انرژی جنبشی کره‌ی توپر می‌آید: `KE = (7/10)mv²`.)

### ⚠ اصلاح مهم — ستون Bounce برای چه چیزی است

در v0.2 این ستون «Wall Bounciness» نام داشت، ولی در Godot (و Unity) یک جسم **یک** مقدار Restitution دارد که هم روی برخورد با دیوار اعمال می‌شود هم روی **برخورد تیله با تیله**.

با مقدار `0.35` که v0.2 داده بود، هر برخورد تیله‌به‌تیله حدود ۴۴٪ انرژی را نابود می‌کرد. نتیجه در تست: یک Shot تمام‌قدرت و دقیق، Targetی را فقط تا شعاع `0.94 m` می‌برد در حالی که برای Ring Out به `1.55 m` نیاز است — یعنی **بازی عملاً غیرقابل‌برد بود** و مهم‌تر از آن، Chain Reaction که §89 هسته‌ی حس بازی می‌داندش اصلاً اتفاق نمی‌افتاد.

شیشه‌ی واقعی Restitution حدود `0.9` دارد. با اعداد جدول بالا همان Shot الان Target را دقیقاً به `1.55` می‌رساند.

ترتیب نسبی حفظ شده (Sticky کمترین، Rubber بیشترین)، ولی **Rubber دیگر تنها تیله‌ی «جهنده» نیست** — صرفاً جهنده‌ترین است. این بهای لازم برای داشتن برخوردهای تُرد بود.

Restitution روی Travel Distance اثری ندارد (کف میز `bounce = 0` است و تیله نمی‌پرد) — با تست تأیید شد.

---

## 26. Heavy Marble

**High Momentum.** در برخورد با Standard، Push بیشتری دارد ولی خودش کندتر حرکت می‌کند.

Momentum در لحظه‌ی شلیک: `6.50 N·s` در برابر `5.20` برای Standard — یعنی ۲۵٪ بیشتر، با سرعت ۲۲٪ کمتر. این دقیقاً رفتار موردنظر است.

---

## 27. Rubber Marble

**High Bank Bounce.** Target 100% Travel: `5.80 m ±10%`

هیچ Bounce عمودی قابل‌توجهی روی Floor ندارد (`floor.bounce = 0`). Bounce اصلی مربوط به Bank Surfaceها است.

> به §9 مراجعه کنید: با گزینه A، Rubber فقط در Levelهایی با Obstacle یا Bumper مفید است.

---

## 28. Precision Marble

**Control.** Target 100% Travel: `3.60 m ±10%`

```text
Aim Guide — Standard  : 1.40 m
Aim Guide — Precision : 2.40 m
```

**اصلاح نسبت به v0.2:** v0.2 می‌گفت «Power Meter آن ۲۵٪ کندتر حرکت می‌کند». ولی Power با Click + Drag تعیین می‌شود (§8 در GDD v0.1) — یک Drag سرعت ندارد. معادل درست همان مفهوم:

```text
Power Drag Length — Standard  : 100%
Power Drag Length — Precision : 125%
```

یعنی برای همان بازه‌ی 0…1 قدرت، باید ۲۵٪ بیشتر Drag کنید → هر پیکسل حرکت موس تغییر کمتری در Power می‌دهد → کنترل دقیق‌تر. همان نیت، سازگار با Input واقعی.

---

## 29. Sticky Marble

**Rapid Stop / Position Control.** Target 100% Travel: `2.80 m ±10%`

Sticky به سطح نمی‌چسبد. فقط Friction بالا، Damping بالا، Bounce بسیار کم.

---

## 30. Magnet Marble

وقتی برای اولین بار Settle شود، `OnStop` تریگر می‌شود:

```text
Radius           = 0.75 m
Max Pull Impulse = 0.55 N·s

Strength = 1 - (Distance / Radius)
Impulse  = 0.55 × Strength
```

Magnet خودش کشیده نمی‌شود. هر Magnet **فقط یک Pulse در هر Match** دارد.

**محدوده‌ی واقعی اثر:** نزدیک‌ترین فاصله‌ی ممکن بین دو مرکز `0.20 m` است، پس حداکثر Strength عملی `0.73` و حداکثر Impulse `0.40 N·s`. روی یک Marble با جرم ۱، این یعنی `Δv = 0.40 m/s` و جابه‌جایی حدود `0.39 m`. برای طراحی Level این سقف را در نظر بگیرید — Magnet یک Reposition ظریف است، نه یک جاروی قدرتمند.

---

## 31. تعریف دقیق Settle

Marble وقتی Settled است که:

```text
Linear  Speed <= 0.035 m/s
Angular Speed <= 0.60  rad/s
```

به‌طور پیوسته برای حداقل:

```text
0.30 s     →  36 Physics Ticks در 120 Hz
```

این دو آستانه با هم سازگارند: یک کره‌ی غلتان با `r = 0.10` در سرعت خطی `0.035` سرعت زاویه‌ای `0.35 rad/s` دارد — زیر آستانه. پس در حالت Rolling عملاً آستانه‌ی خطی تعیین‌کننده است و آستانه‌ی زاویه‌ای فقط چرخش درجا را می‌گیرد.

### Velocity Floor — اضافه‌شده نسبت به v0.2

Damping نمایی هیچ‌وقت به صفر نمی‌رسد. یک Shot تمام‌قدرت Standard از `5.20` تا `0.035 m/s`:

```text
t = ln(5.20 / 0.035) / 1.03 = 4.86 s
```

به‌علاوه‌ی `0.30 s` انتظار → نزدیک **۵.۲ ثانیه** تا پایان نوبت، که بیشترش تماشای یک تیله‌ی تقریباً ساکن است.

برای همین، زیر `0.50 m/s` یک کاهش شتاب ثابت هم اعمال می‌شود:

```text
if (speed < 0.25) apply deceleration 0.80 m/s² against velocity
```

این دم حرکت را حدود **۲ ثانیه** کوتاه می‌کند.

**آستانه عمداً پایین است.** Floor یک مقدار *ثابت* از هر Shot کم می‌کند، پس آستانه‌ی بالا منحنی Power→Distance را از خطی بودن دور می‌کند و Shotهای آرام را به‌طور نامتناسبی ضعیف می‌کند. با `0.50` در تست، Shot با قدرت ۲۵٪ حدود ۲۴٪ کوتاه می‌آمد؛ با `0.25` این خطا به ۸٪ رسید (داخل تلورانس).

---

## 32. Settle Snap

بعد از تأیید Settled:

```csharp
LinearVelocity  = Vector3.Zero;
AngularVelocity = Vector3.Zero;
Sleeping        = true;
```

این Jitter انتهایی را حذف می‌کند.

---

## 33. OnStop Rule

`OnStop` فقط اولین باری که Marble بعد از Shot خودش Settle می‌شود تریگر می‌شود. اگر بعداً Marble دیگری آن را حرکت دهد و دوباره بایستد، Ability دوباره تریگر نمی‌شود.

```text
HasTriggeredStopAbility = true
```

---

## 34. Physics Resolution End

Shot Resolution وقتی تمام می‌شود که:

1. تمام Marbleهای Dynamic، Settled باشند.
2. هیچ Ability ـی Pending نباشد.
3. وضعیت برای `0.20 s` پایدار بماند.

---

## 35. Physics Timeout

**اصلاح نسبت به v0.3 اولیه — Sweep پلکانی به جای یک پرتگاه.** در تست معلوم شد یک Shot تنها طی ~۳.۳ ثانیه می‌ایستد، ولی Resolution کامل (با Targetهای پراکنده) تا ۶ ثانیه طول می‌کشید؛ بیشترش انتظار برای یک تیله‌ی عقب‌مانده بود که دارد می‌خزد. به‌جای یک Timeout در ۱۰ ثانیه:

```text
t > 3 s   →  force settle هر چیزی با speed < 0.30
t > 7 s   →  force settle هر چیزی با speed < 0.80
t > 11 s  →  force settle همه چیز   (Hard)
```

هر مرحله سرعت را طی `0.30 s` پایین می‌آورد و Ring Out در طول همین Ramp هم چک می‌شود، پس از تیله‌ای که داشت امتیاز می‌گرفت چیزی دزدیده نمی‌شود. میانگین Resolution به ~۳.۵ ثانیه رسید.

**Soft:** اگر بعد از ۱۰ ثانیه فقط Marbleهایی با `speed < 0.15 m/s` مانده باشند، Force Settle می‌شوند.

**اصلاح نسبت به v0.2:** Force Settle نباید سرعت را در یک Frame صفر کند. `0.15 m/s` بیش از چهار برابر آستانه‌ی Settle است و توقف ناگهانی روی لبه‌ی Ring به چشم می‌آید و ناعادلانه حس می‌شود. سرعت طی `0.30 s` به صفر Ramp می‌شود، و شرط Ring Out (§36) **در طول این Ramp هم بررسی می‌شود**.

**Hard:** در ۱۵ ثانیه همه Force Settle می‌شوند (با همان Ramp). Event:

```text
PhysicsHardTimeout
```

در Telemetry ثبت می‌شود. هدف: تقریباً صفر در Release Build.

---

## 36. Ringer — Rule کامل

Ring یک Boundary منطقی است. Target وقتی Ring Out است که:

```text
Distance(TargetCenter, RingCenter) >= RingRadius + MarbleRadius
                                   >= 1.45 + 0.10
                                   >= 1.55 m
```

در آن لحظه:

```text
TargetState = Captured
```

و Score فوراً Lock می‌شود — Target دیگر نمی‌تواند برگردد.

### اصلاح نسبت به v0.2 — زمان حذف

v0.2 می‌گفت Target بعد از `0.15 s` از Arena حذف شود. حذف یک بدنه‌ی فیزیکی **وسط Resolution** نتیجه‌ی بقیه‌ی برخوردها را عوض می‌کند و باعث می‌شود Simulator پیش‌بینی AI (§19) مجبور شود دقیقاً همین حذف را در همان Tick بازتولید کند.

به جایش:

- در لحظه‌ی عبور از `1.55`: `Captured = true`، Score قفل، Collision Layer به `CapturedDebris` تغییر می‌کند (دیگر با Marbleهای فعال برخورد نمی‌کند، ولی از زمین نمی‌افتد).
- حذف واقعی از Scene **بعد از پایان Physics Resolution** انجام می‌شود.

نتیجه: تصویر همان است، شبیه‌سازی تمیزتر.

---

## 37. Ringer — Player Marble

خارج شدن Marble بازیکن از Ring هیچ اتفاق خاصی ایجاد نمی‌کند. فقط Target Marbleها Ring Out می‌شوند.

---

## 38. Arena Out

Arena Out با Ring Out فرق دارد. وقتی اتفاق می‌افتد که Marble از سطح میز خارج شود.

```text
OutTrigger  = 0.08 m بیرون از Edge
Kill Plane  = Y -0.30 m        (Fail-Safe)
```

---

## 39. Holes

```text
Visual Radius  = 0.18 m
Capture Radius = 0.16 m
```

اگر مرکز افقی Marble وارد Capture Radius شود:

```text
State = Sunk
```

سپس Collider غیرفعال، انیمیشن کوتاه سقوط، حذف از Simulation.

---

## 40. Own Marble داخل Hole

در Standard Holes Mode، اگر Marble بازیکن داخل Hole بیفتد:

- Objective Point نمی‌گیرد
- `Lost` محسوب می‌شود
- Stage Score: `-250`
- Stage فوراً Fail نمی‌شود

---

## 41. Target Marble داخل Hole

```text
Objective Progress +1
```

در Vertical Slice تمام Target Marbleهای Holes معتبرند. Target اشتباه نداریم.

---

## 42. Target خارج از Arena در Holes

اگر Target به جای Hole از Arena خارج شود، `Lost` می‌شود و Objective Credit ندارد.

اگر بعد از آن از نظر ریاضی امکان Complete شدن Objective نماند، Stage فوراً `Defeat` می‌شود.

> در Ringer این حالت رخ نمی‌دهد: هر مسیری برای خروج از Arena اول از مرز `1.55` رد می‌شود، پس Target همیشه قبل از افتادن Capture شده است.

---

## 43. Knockout — Turn Order

Player و AI هرکدام Bag هشت‌تایی دارند. Default: **Player Starts.**

```text
Player → AI → Player → AI → …
```

هر Actor در هر Turn یک Marble از Reserve وارد می‌کند و یک Shot می‌زند.

Marbleهای Reserve در Arena نیستند، پس نمی‌توانند Knock Out شوند — هر دو طرف همیشه هر ۸ Shot خود را دارند.

---

## 44. Knockout Duration

هر طرف `8 Turn` → Match کامل `16 Turn`. بعد از آخرین Shot و پایان Physics، Match Resolve می‌شود.

---

## 45. Knockout Match Points

```text
AI marble leaves Arena      →  Player +1
Player marble leaves Arena  →  AI     +1
```

علت خروج مهم نیست. اگر بازیکن Marble خودش را بیرون بیندازد، AI همچنان امتیاز می‌گیرد.

---

## 46. Knockout Win

```text
PlayerPoints > AIPoints   →  Win
PlayerPoints < AIPoints   →  Lose
```

---

## 47. Knockout Tie Break

برای تمام Marbleهای زنده‌ی هر طرف:

```text
EdgeSafety = minimum distance to nearest Arena edge
```

مجموع EdgeSafety هر طرف محاسبه می‌شود. طرف با مجموع بیشتر برنده است.

این معیار با منطق Knockout هم‌خوان است: Marble نزدیک لبه بیشتر در خطر است. (برخلاف v0.2 ـ GDD که معیار «فاصله از مرکز» را از King of the Ring قرض گرفته بود.)

مقایسه عادلانه است چون تساوی امتیاز یعنی هر دو طرف به تعداد برابر Marble از دست داده‌اند، پس تعداد بازمانده‌ها هم برابر است.

```text
|Difference| < 0.01 m   →  Draw
```

در Campaign: Draw = Level Not Completed.

---

## 48. Scoring و Win Condition جدا هستند

- **Match Result** تعیین می‌کند Level برده شده یا نه.
- **Stage Score** برای Best Score، Replayability و Medalهای آینده است.

Score هیچ‌وقت Win Condition را جایگزین نمی‌کند.

---

## 49. Base Score Events

| Event | Score |
|---|---:|
| Objective Target Ring Out | +1000 |
| Valid Target Sunk | +1000 |
| Enemy Marble Knocked Out | +1000 |
| Own Marble Lost | −250 |
| Unused Shot on Victory | +200 each |

**اصلاح:** «Unused Shot» فقط در Modeهای Shot-Limited (**Ringer** و **Holes**) معنی دارد. در Knockout هر دو طرف همیشه هر ۸ نوبت را بازی می‌کنند، پس این Bonus آنجا اعمال نمی‌شود.

---

## 50. Bank Shot

ثبت می‌شود وقتی:

1. Shooter Marble حداقل یک **Bank Surface** را لمس کند،
2. قبل از تماس مستقیم با Objective Target،
3. و همان Shot حداقل یک Scoring Event ایجاد کند.

```text
Bonus = +150        (حداکثر یک بار در هر Shot، حتی با پنج برخورد)
```

> «Bank Surface» طبق §9 یعنی Obstacle Wall و Bumper.

---

## 51. Multi Hit

Shooter Marble در یک Shot مستقیماً با حداقل **دو Objective-Relevant Marble** برخورد کند.

**تعریف Objective-Relevant Marble:** هر Marbleی که وضعیتش می‌تواند Objective فعلی Stage را جلو ببرد — در Ringer و Holes یعنی Target Marbleها، در Knockout یعنی Marbleهای حریف.

```text
+75 به ازای هر Target مستقیم بعد از اولی
3 Direct Targets  →  +150
```

---

## 52. Chain Hit

اگر Shooter، Target A را بزند و A باعث شود Target B یک Scoring Event ایجاد کند، در حالی که Shooter مستقیماً B را لمس نکرده:

```text
+125 به ازای هر Scoring Target غیرمستقیم
```

---

## 53. Combo

در MVP، **Combo یک سیستم Score جدا نیست.** فقط Presentation است.

سه Scoring Event در یک Shot → UI نشان می‌دهد `3× COMBO`، ولی هیچ Multiplier اضافه‌ای روی Score اعمال نمی‌شود.

این تصمیم جلوی Double-Dipping بین Multi Hit، Chain و Combo را می‌گیرد.

---

## 54. Perfect Shot

اگر یک Shot تمام Objectiveهای باقی‌مانده را Complete کند:

```text
Perfect Finish  →  +300
```

Presentation: `0.25 s` Slow Motion، Camera Punch، صدای مخصوص، متن `PERFECT FINISH`.

---

## 55. Best Level Score

فقط در صورت Victory:

```text
BestScore = max(CurrentScore, PreviousBestScore)
```

Defeat هیچ Best Score جدیدی ثبت نمی‌کند.

---

## 56. ShotContext

برای هر Shot یک Context ساخته می‌شود:

```text
ShotId
ActorId
MarbleId
StartPosition
Direction
Power
TouchedBankSurfaces
DirectHitTargetIds
IndirectHitTargetIds
RingOutEvents
SinkEvents
KnockoutEvents
AbilityEvents
ScoreEvents
```

بعد از Physics Resolution بسته می‌شود. Bank Shot، Multi Hit، Chain و Combo همه از همین Context محاسبه می‌شوند.

---

## 57. Deck Rule — PvE

```text
Default Bag Size = 8
Standard         = Unlimited Copies
Special Marble   = Max 1 Copy per Type
```

با پنج Special موجود، سقف طبیعی `5 Special + 3 Standard` است.

نمونه‌ی معتبر: `Standard ×3، Heavy، Rubber، Precision، Sticky، Magnet`

---

## 58. Trial Exception

در Marble Trial، یک Marble قفل‌شده به‌صورت **Loaned Marble** موقتاً وارد Deck می‌شود. بازیکن مالک آن نیست. بعد از Complete شدن Trial، دائمی Unlock می‌شود.

---

## 59. Objective Tiers — تعریف‌شده نسبت به v0.2

v0.2 در چند Level عبارت «Additional Requirement» را کنار Primary و Secondary می‌آورد بدون اینکه بگوید نبودنش Level را Fail می‌کند یا نه. تعریف:

| Tier | اثر |
|---|---|
| **Primary** | برای Complete شدن Level الزامی است |
| **Additional** | بخشی از Primary است. در Trialها استفاده می‌شود تا بازیکن مجبور شود واقعاً با Marble جدید بازی کند، نه اینکه آن را کنار بگذارد. **نبودنش = Level کامل نشده** |
| **Secondary** | اختیاری. فقط برای Score و Medal. هیچ‌وقت جلوی Progression را نمی‌گیرد |

---

## 60. AI Difficulty

```text
Easy
Normal
Hard
```

در Vertical Slice فقط `Easy` و `Normal` لازم‌اند.

| | Candidates | Aim Error | Power Error |
|---|---:|---:|---:|
| Easy | 24 | ±4.0° | ±8% |
| Normal | 64 | ±1.5° | ±3% |
| Hard | 160 | ±0.8° | ±1% |

**اصلاح:** v0.2 برای Hard خطای `±0.4°` گذاشته بود. روی یک Shot دو متری این `0.014 m` انحراف است — **کمتر از خطای ۰.۰۵ متری خودِ Prediction (§20).** یعنی Hard از Normal قابل تفکیک نبود و عملاً نویز Simulator تعیین‌کننده می‌شد. `±0.8°` (حدود `0.028 m`) حداقل فاصله‌ای است که معنی‌دار بماند.

Hard برای Vertical Slice لازم نیست.

---

## 61. AI Candidate Generation

برای هر Candidate:

1. Marble انتخاب
2. Placement انتخاب
3. Target Point
4. Angle
5. Power
6. اجرا در Simulator (§19)
7. امتیازدهی به Outcome

بهترین Candidate انتخاب می‌شود، سپس Difficulty Error اعمال می‌شود.

### Budget — اضافه‌شده نسبت به v0.2

«Candidate Count» در §60 **کل بودجه** است، نه تعداد زاویه‌ها. تقسیم پیشنهادی برای Normal (۶۴):

```text
Marble       : 2 کاندید برتر از Reserve (با Heuristic ساده)
Placement    : 4 نقطه در Launch Zone
Angle        : 4 زاویه حول خط دید به هدف منتخب
Power        : 2 سطح
                                   = 2 × 4 × 4 × 2 = 64
```

**Think-Time Budget:**

```text
Hard limit = 1.5 s
```

اگر بودجه تمام شد، بهترین Candidate تا آن لحظه انتخاب می‌شود. AI روی Thread جدا اجرا می‌شود و UI هیچ‌وقت Freeze نمی‌کند. زمان واقعی در Telemetry ثبت می‌شود: `AIThinkTimeMs`.

---

## 62. AI Knockout Evaluation

```text
Enemy Knockout        +1000
Enemy Toward Edge      +100
Self Knockout         -1200
Self Toward Edge       -100
Good Center Safety      +40
Multi Enemy Contact     +30
```

این اعداد فقط AI Utility هستند و به Player Score ربطی ندارند.

---

## 63. Camera — اضافه‌شده نسبت به v0.2

v0.2 هیچ مشخصاتی برای دوربین نداشت، در حالی که Phase 1 بدون آن قابل ساخت نیست.

```text
Node            : Camera3D (Perspective)
Position        : (0, 4.20, -3.55)
Look At         : (0, 0, 0)
FOV (vertical)  : 45°
Near / Far      : 0.10 / 50.0
```

با این تنظیم در 16:9، محدوده‌ی دیده‌شده روی زمین تقریباً `8.1 × 5.9 m` است — یعنی کل Arena با حدود ۱۲٪ حاشیه. Launch Zone بازیکن پایین کادر و Launch Zone حریف بالای کادر قرار می‌گیرد.

دوربین **ثابت** است. بازیکن کنترلش نمی‌کند. فقط Camera Punch و Slow-Motion Zoom در لحظات Impact روی آن اعمال می‌شود (§81).

---

## 64. Vertical Slice — دقیقاً ۱۰ Level

تمام Positionها `Vector2(X, Z)` هستند و در مختصات Arena، نه محلی.

---

### Level 01 — First Flick

**Mode:** Ringer · **Ring:** R = 1.45 · **Shot Limit:** 8

```text
Player Bag : 8× Standard
Targets    : (-0.22,  0.00)
             ( 0.22,  0.00)
             ( 0.00,  0.22)
             ( 0.00, -0.22)
```

- **Primary:** Ring Out 2 Targets
- **Secondary:** Complete within 6 Shots
- **Reward:** Deck Builder Unlocked

**Purpose:** Select → Place → Aim → Power → Flick → Ring Out

---

### Level 02 — Break the Cluster

**Mode:** Ringer · **Shot Limit:** 8 · **Available:** Standard only

```text
Targets : (-0.32,  0.00)   ( 0.32,  0.00)
          (-0.16,  0.28)   ( 0.16,  0.28)
          (-0.16, -0.28)   ( 0.16, -0.28)
```

- **Primary:** Ring Out 4
- **Secondary:** Score one Multi Hit

**Purpose:** معرفی Chain Collision.

---

### Level 03 — Precision Trial

**Mode:** Ringer · **Shot Limit:** 7 · **Loaned:** 1× Precision · **Deck:** 1 Precision + 7 Standard

```text
Targets : (-0.40, 0.10)  (-0.15, 0.10)
          ( 0.10, 0.10)  ( 0.35, 0.10)
          ( 0.00, 0.40)
```

- **Primary:** Ring Out 3
- **Additional:** Precision Marble must directly hit at least one Target
- **Reward:** Precision Unlocked

---

### Level 04 — First Hole

**Mode:** Holes · **Shot Limit:** 8 · **Available:** Standard, Precision

```text
Hole    : ( 0.00, 0.70)
Targets : (-0.65,  0.20)
          ( 0.65,  0.20)
          ( 0.00, -0.45)
```

- **Primary:** Sink 2 Targets
- **Secondary:** Lose no Player Marble

**Purpose:** قوانین Hole.

---

### Level 05 — Heavy Trial

**Mode:** Ringer · **Shot Limit:** 7 · **Loaned:** Heavy

```text
Targets : ( 0.00,  0.00)
          ( 0.24,  0.00)   (-0.24,  0.00)
          ( 0.12,  0.22)   (-0.12,  0.22)
          ( 0.12, -0.22)   (-0.12, -0.22)
```

- **Primary:** Ring Out 5
- **Additional:** Heavy Marble must cause at least one Ring Out
- **Reward:** Heavy Unlocked

> **اصلاح نسبت به v0.2:** چیدمان اصلی `(±0.11, ±0.20)` و `(±0.22, 0)` بود. فاصله‌ی مرکز تا مرکز بین `(0.11, 0.20)` و `(-0.11, 0.20)` دقیقاً `0.22 m` می‌شد، یعنی فقط `0.02 m` فاصله‌ی سطح‌به‌سطح — به اندازه‌ای نزدیک که Solver در فریم اول Penetration و Jitter بدهد. فاصله‌ها به `0.24` و `(±0.12, ±0.22)` باز شدند؛ حداقل فاصله‌ی مرکزها حالا `0.25 m` است.

---

### Level 06 — Around the Wall

**Mode:** Ringer · **Shot Limit:** 7 · **Loaned:** Rubber

```text
Obstacle Wall
  Center : ( 0.00, -0.10)
  Size   : X 1.20  ·  Y 0.30  ·  Z 0.12
  Rotation: 0°

Targets : (-0.50, 0.55)   ( 0.00, 0.60)
          ( 0.50, 0.55)   ( 0.00, 0.90)
```

- **Primary:** Ring Out 3
- **Additional:** Rubber Marble must create one scoring Bank Shot
- **Reward:** Rubber Unlocked

> **اصلاح نسبت به v0.2:** ابعاد `1.20 × 0.12 × 0.20` بود، بدون اینکه ترتیب محورها مشخص باشد. در هر دو تفسیر، ارتفاع دیوار (`0.12` یا `0.20`) **کمتر یا مساوی قطر Marble** (`0.20`) می‌شد؛ مرکز Marble در `Y = 0.10` است و تیله از روی چنین دیواری بالا می‌رفت یا به هوا پرت می‌شد. ارتفاع به `0.30 m` رسید و ترتیب محورها صریح نوشته شد.
>
> **قانون عمومی:** ارتفاع هر Obstacle و Bumper حداقل `0.30 m` باشد. Level Validator (§66) این را چک می‌کند.

---

### Level 07 — Magnetic Pull

**Mode:** Holes · **Shot Limit:** 7 · **Loaned:** Magnet

```text
Hole    : ( 0.00, 0.35)
Targets : (-0.42, 0.35)   ( 0.42, 0.35)
          ( 0.00, 0.78)   ( 0.00,-0.10)
```

- **Primary:** Sink 2 Targets
- **Additional:** Magnet Pulse must affect at least 2 Targets
- **Reward:** Magnet Unlocked

> ⚠ **این Level باید قبل از Lock شدن بازی شود.** دو مشکل بالقوه:
> ۱. Magnet تیله‌ها را **به سمت خودش** می‌کشد، پس اگر پشت Hole متوقف نشود، Targetها را از Hole دور می‌کند — Ability مستقیماً با Objective می‌جنگد.
> ۲. طبق §30 حداکثر جابه‌جایی ناشی از Pulse حدود `0.39 m` است، در حالی که Targetهای کناری `0.42 m` با Hole فاصله دارند. یعنی Pulse به‌تنهایی هیچ‌وقت کافی نیست و فقط Setup است.
>
> اگر هدف این است که Magnet واقعاً حس قدرت بدهد، یا `Max Pull Impulse` بالا برود یا Targetها نزدیک‌تر چیده شوند.

---

### Level 08 — First Duel

**Mode:** Knockout · **AI:** Easy · **Player Starts:** Yes · **Obstacles:** None

```text
Player Bag : Custom 8
Available  : Standard, Precision, Heavy, Rubber, Magnet
AI Bag     : 8× Standard
```

- **Primary:** Win Match
- **Secondary:** Knock Out at least 3 AI Marbles
- **Reward:** Sticky Trial Unlocked

> با گزینه A در §9 (میز بدون دیوار)، Rubber در این Level هیچ Bank Surface ـی ندارد.

---

### Level 09 — Hold Your Ground

**Mode:** Knockout · **AI:** Easy · **Loaned:** Sticky

```text
Player Deck : باید شامل Sticky باشد
AI Deck     : 6 Standard, 1 Heavy, 1 Precision
```

- **Primary:** Win Match
- **Additional:** Sticky Marble must still be inside Arena at Match End
- **Reward:** Sticky Unlocked

---

### Level 10 — Final Table

**Mode:** Knockout · **AI:** Normal · **Player:** Free Deck Builder، هر شش نوع

```text
AI Bag  : 3 Standard, 1 Heavy, 1 Rubber, 1 Precision, 1 Sticky, 1 Magnet

Bumper A : (-0.85, 0.00)   Radius 0.18   Height 0.30
Bumper B : ( 0.85, 0.00)   Radius 0.18   Height 0.30
```

- **Primary:** Win Match
- **Secondary 1:** Score one Bank Shot
- **Secondary 2:** Lose no more than 3 Marbles
- **Reward:** Chapter 1 Complete

---

## 65. Stage Coordinate Convention

تمام Positionهای Stage Data به شکل `Vector2(X, Z)` ذخیره می‌شوند. مقدار `Y` در Runtime بر اساس نوع Object تعیین می‌شود:

```text
Marble    →  Y = Radius = 0.10
Hole      →  Y = 0
Obstacle  →  Y = Height / 2
```

---

## 66. Level Validation Tool

یک Godot `EditorScript` / Plugin که قبل از Play و در CI اجرا می‌شود و این‌ها را چک می‌کند:

- Target Overlap (حداقل فاصله‌ی مرکزها `0.25 m` در چیدمان Authored)
- Obstacle Overlap
- Invalid Hole Placement
- Ring outside Arena
- **Launch Zone (شامل هر دو مرحله‌ی Expansion) نباید با Ring تداخل کند**
- Launch Zone intersection with static obstacle
- **ارتفاع هر Obstacle و Bumper `>= 0.30 m`**
- Impossible Objective Count
- Missing Reward
- Missing Primary Objective
- Duplicate Object IDs
- **هر Level که Additional Objective وابسته به Bank Shot دارد باید حداقل یک Bank Surface داشته باشد**

Level دارای Error نباید Build شود.

---

## 67. MarbleDefinition

یک `Resource` سفارشی که به‌صورت `.tres` ذخیره می‌شود (معادل Godot برای ScriptableObject).

```text
Id
DisplayNameKey
DescriptionKey
Scene              (PackedScene)
Icon
Radius
Mass
ShotMultiplier
LinearDamping
AngularDamping
Friction
BankBounciness
AimGuideLength
PowerDragScale
AbilityId
Tags
```

---

## 68. LevelDefinition

`Resource` → `.tres`

```text
LevelId
DisplayNameKey
GameModeId
ArenaDefinition
PlayerStart
PlayerBagRules
LoanedMarbles
AIConfig
ShotLimit
LaunchZones
Targets
Holes
Obstacles
PrimaryObjectives
AdditionalObjectives
SecondaryObjectives
Rewards
```

---

## 69. ShotCommand

هیچ Human یا AI Controller مستقیماً به RigidBody3D دست نمی‌زند. اول `ShotCommand` ساخته می‌شود:

```text
ShotId
ActorId
MarbleInstanceId
PlacementPosition
Direction
Power
SimulationTick
```

سپس Game Simulation آن را اجرا می‌کند.

---

## 70. Multiplayer Compatibility

این Architecture عمداً برای PvP آینده آماده می‌شود:

```text
Client  →  ShotCommand  →  Host
Host    :  Validate → Simulate → Authoritative Result  →  Client
```

بنابراین نیازی نیست Physics دو دستگاه دقیقاً Deterministic باشد.

---

## 71. Input

Godot Input Map — Action Group `gameplay`:

```text
point
select
cancel
aim
power
shoot
pause
```

Controller: `navigate`، `confirm`، `cancel`، `aim`، `shoot`، `pause`

Gameplay Code مستقیماً `Input.IsKeyPressed` یا موقعیت خام موس را Query نمی‌کند. همه‌چیز از Action System عبور می‌کند.

---

## 72. Telemetry

حتی در Development Build این داده‌ها در یک JSON محلی Log شوند (`user://telemetry/`). نیازی به سرویس Online نیست.

```text
StageId            AttemptCount        CompletionTime
ShotsUsed          ShotPower           ShotAngle
MarbleType         MarblePlacement     Score
RingOutCount       SinkCount           KnockoutCount
BankShotCount      MultiHitCount       ChainCount
PhysicsHardTimeout LaunchZoneEmergencyUsed
AIThinkTimeMs      ShotResolveTimeMs
```

---

## 73. Phase 1 Acceptance Test

Standard Marble روی Arena خالی:

| Test | Power | Average Distance |
|---|---|---|
| A | 25% | 1.25 m ±10% (۲۰ Shot) |
| B | 50% | 2.55 m ±10% |
| C | 100% | 5.05 m ±10% |

**Test D — Repeatability:** از State یکسان، ۱۰۰ Shot با Position / Direction یکسان و `Power = 0.75`، روی یک Machine و Build:

```text
Final position spread <= 0.02 m
```

هدف Reproducibility است، نه اثبات Cross-Platform Determinism. این تست فقط وقتی معنی دارد که هیچ نیرویی خارج از `_PhysicsProcess` اعمال نشود.

**Test E — Settle Time (اضافه‌شده):** Shot تمام‌قدرت Standard باید حداکثر `3.5 s` بعد از رها شدن Settle شود. اگر بیشتر طول کشید، §31 (Velocity Floor) تنظیم می‌شود.

---

## 74. Collision Feel Acceptance

Standard با Power 75% به Standard Target می‌خورد. نتیجه باید:

- Collision واضح باشد
- Target فوراً Momentum قابل مشاهده بگیرد
- Shooter تمام انرژی خود را از دست ندهد
- هیچ Jitter غیرعادی نباشد
- کره‌ها Penetrate نکنند

---

## 75. Phase 1 — دامنه

**هست:**
Godot Project Setup · Forward+ · Jolt · Input Map · Fixed 120 Hz Tick · Arena 7.2×4.8 · Camera · Standard Marble · Placement · Aim · Power · ShotCommand · Rolling Physics · Collision · Settle Detection · Ring · Ring Out · Restart · Debug Overlay

**نیست:**
Special Marble · AI · Deck Builder · Campaign · Save · Audio Polish · Final UI · Holes · Knockout · Online · PvP

---

## 76. Debug Overlay

در Development Build با `F1`:

```text
FPS                     Physics Tick Rate      Current Tick
Selected Marble         Linear Velocity        Angular Velocity
Power                   Impulse                Settled State
Physics Resolve Time    Active RigidBody Count
```

بدون این ابزار Physics Tuning بیش از حد حدسی می‌شود.

---

## 77. Phase 2 — Match Framework

Game State Machine · Marble Bag · Turn Flow · Objective System · Scoring · Stage Data · Level 01–03

## 78. Phase 3 — Marbles & Holes

Precision · Heavy · Rubber · Sticky · Magnet · Ability Event Framework · Holes · Level 04–07

## 79. Phase 4 — Knockout & AI

Knockout · Shot Simulator (§19) · Easy AI · Normal AI · Level 08–10

## 80. Phase 5 — Progression

Collection · Deck Builder · Unlocks · Save System · Campaign Flow · Secondary Objectives · Best Scores

## 81. Phase 6 — Polish

Final Marble Materials · VFX · Camera Punch · Slow Motion · Collision Audio · UI Animation · Transitions · Accessibility · Controller Pass

---

## 82. Timeline

### دو برنامه‌نویس Core

| هفته | کار |
|---|---|
| 1–2 | Core Physics |
| 3 | Turn / Match Framework |
| 4–5 | Marble Architecture + Ringer + Holes |
| 6–7 | Knockout + AI |
| 8–9 | Progression + ۱۰ Level |
| 10–11 | UI / Art / Audio / Game Feel |
| 12 | Balancing |
| 13 | QA / Fixes |

**Reference Target: 13 weeks**

### تک‌نفره

برای یک Godot Developer باتجربه که Art و Audio را ساده نگه دارد: **18–24 هفته**

برای Developer کم‌تجربه نباید روی این Timeline حساب کرد. Physics Tuning و AI بیشترین زمان غیرقابل‌پیش‌بینی را دارند.

**به‌علاوه‌ی Spike §19:** اگر Simulator اختصاصی لازم شود، یک تا دو هفته به فاز AI اضافه می‌شود.

---

## 83. Vertical Slice — Definition of Done

- هر ۱۰ Level قابل بازی
- هر ۶ Marble کار می‌کند
- Ringer، Holes و Knockout کامل
- Easy AI و Normal AI کار می‌کنند
- Collection، Deck Builder و Save/Load کار می‌کنند
- Controller کار می‌کند
- هیچ Physics Softlock شناخته‌شده‌ای نیست
- Retry زیر ۲ ثانیه
- `PhysicsHardTimeout` کمتر از `0.1%` Shotها
- میانگین Settle Time کمتر از `3.5 s`

---

## 84. عمداً قفل‌نشده

این‌ها Phase 1 را Block نمی‌کنند:

Final Art Style · Final Game Name · Final Music Style · Steam Price · Achievement List · تعداد Chapterهای Campaign کامل · Cosmetic Economy · PvP Draft Details · Steam Networking Implementation (GodotSteam یا Steamworks.NET)

---

## 85. تصمیم‌های باز که باید بسته شوند

| # | موضوع | اثر |
|---|---|---|
| 1 | §9 — دیوار پیرامونی: گزینه A یا B | **Phase 1 را بلاک می‌کند** |
| 2 | §19 — نتیجه‌ی Spike روی Simulator | Phase 4 را بلاک می‌کند، ولی Spike باید در هفته‌ی اول انجام شود |
| 3 | §27 / §9 — Rubber در ۸ Level از ۱۰ بی‌استفاده است | Balance |
| 4 | §64 Level 07 — Magnet با Objective خودش می‌جنگد | Level Design |
| 5 | نسخه‌ی دقیق Godot | باید در `project.godot` Pin شود |

---

## 86. مهم‌ترین Technical Rule پروژه

**Physics Feel با Numberها تعریف نمی‌شود؛ Numberها فقط Baseline هستند.**

```text
Known Input → Predictable Motion → Readable Collision → Satisfying Impact
```

اگر `LinearDamping = 1.03` باشد ولی Feel بد باشد، حفظ آن عدد هیچ ارزشی ندارد.

اما تغییر هر Physics Value باید همراه با **Test**، **Measurement** و **Updated Travel Target** باشد — نه صرفاً «این بهتر حس می‌شود».

---

## 87. Phase 1 Go / No-Go

بعد از Phase 1 فقط یک سؤال داریم:

> آیا Standard Marble بدون Ability، Progression، Unlock و AI به‌اندازه‌ی کافی سرگرم‌کننده است؟

**بله** → Development ادامه پیدا می‌کند.

**نه** → Special Marble و Content بیشتر نمی‌سازیم. اول Shot Feel، Collision، Camera، Audio، Power Control و Travel Distance اصلاح می‌شوند.

این Gate باید جدی گرفته شود.
