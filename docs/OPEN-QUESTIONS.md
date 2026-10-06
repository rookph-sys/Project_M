# Open Questions — چیزهایی که GDD v0.1 کم دارد

مرتب‌شده بر اساس اینکه چه چیزی **امروز** Phase 1 را بلاک می‌کند.

---

## A. بلاک‌کننده Phase 1 (Core Physics) — بدون این‌ها نمی‌شود کد زد

### A1. مقیاس و واحدها
سند هیچ عددی برای ابعاد ندارد. لازم است:
- Arena: طول × عرض بر حسب متر
- Ring: شعاع
- Marble: `Radius` در لیست Stats هست ولی مقدار ندارد (پیشنهاد: ~0.02m تیله واقعی، یا scale بزرگ‌تر برای فیزیک پایدارتر)
- Launch Zone: فاصله از Ring، طول

بدون مقیاس، `BaseShotForce = 10` معنی ندارد.

### A2. Drag / Angular Drag
`MarbleDefinition` این فیلدها را دارد ولی §11 برای هیچ Marbleی مقدار نداده.
این دو عدد کل رابطه `Power → Distance` را می‌سازند — یعنی همان چیزی که §45 مهم‌ترین ویژگی بازی می‌داند.

### A3. Gravity و Roll vs Slide
تیله روی یک Plane تخت: Gravity روشن است؟ تیله **می‌غلتد** یا **می‌لغزد**؟
این تصمیم Feel را بیشتر از هر عدد دیگری عوض می‌کند و در سند اصلاً مطرح نشده.
همچنین: Angular Drag و Friction باید با هم ست شوند وگرنه تیله تا ابد می‌غلتد.

### A4. تعریف «متوقف شد»
§13 رویداد `OnStop` دارد و Magnet به آن وابسته است. §6 می‌گوید منتظر Sleep می‌مانیم.
لازم است: Velocity Threshold و Angular Velocity Threshold و مدت زمان زیر آستانه.

### A5. Fixed Timestep + تناقض Determinism
§85 می‌گوید Shot یکسان = نتیجه یکسان. PhysX در Unity با Framerate متغیر **این را تضمین نمی‌کند**.
باید یکی را انتخاب کنید:
- **الف)** `Physics.Simulate()` دستی با Fixed Step → Determinism واقعی، AI Prediction دقیق، Replay ممکن
- **ب)** پذیرفتن «تقریباً یکسان» و پاک کردن ادعای Determinism از §85

این تصمیم روی §35 (AI Simulation Scene) هم اثر مستقیم دارد: اگر Sim Scene دقیقاً مثل Main Scene قدم نزند، AI اشتباه پیش‌بینی می‌کند.

### A6. Minimum Shot Power و Drag Dead Zone
§47 هر دو را می‌خواهد، هیچ‌کدام عدد ندارند. Drag به Power چطور Map می‌شود؟ خطی؟ با Max Drag Distance چند پیکسل؟

---

## B. قوانین حل‌نشده (Edge Caseها)

| # | سؤال |
|---|---|
| B1 | اگر خود تیله‌ی شلیک‌شده‌ی Player از Arena بیرون برود چه می‌شود؟ §40 می‌گوید «Marble Lost» ثبت می‌شود — ولی جریمه دارد؟ در Ringer اصلاً مهم است؟ |
| B2 | **Ring ≠ Arena Boundary.** Target از Ring بیرون می‌رود ولی داخل Arena می‌ماند → امتیاز می‌گیرد. اگر Shot بعدی دوباره آن را به داخل Ring هل داد چه؟ باید Latch باشد یا برگشت‌پذیر؟ |
| B3 | Placement روی تیله‌ی قبلی: Launch Zone تا پایان Match پر از تیله‌های استفاده‌شده می‌شود. Overlap ممنوع است؟ تیله‌های قبلی کنار می‌روند؟ |
| B4 | Aim آزاد ۳۶۰ درجه است یا فقط به سمت داخل Arena؟ |
| B5 | Shot Limit همیشه مساوی Bag Size (۸) است؟ اگر کمتر باشد، بعضی تیله‌ها اصلاً استفاده نمی‌شوند — عمدی است؟ |
| B6 | **Knockout: ترتیب نوبت.** یک‌درمیان؟ کی اول شروع می‌کند؟ §17.2 نمی‌گوید. |
| B7 | تیله‌ای که در ثانیه‌ی ۸ با Damping متوقف شده ولی هنوز کنار خط Ring است، اگر در Turn بعدی از خط رد شود، امتیاز کِی ثبت می‌شود؟ |
| B8 | Holes: Player تیله‌ی **خودش** را داخل Hole بیندازد = باخت؟ از دست رفتن؟ هیچی؟ چند Hole در یک Arena؟ |

---

## C. سیستم‌هایی که اسم دارند ولی طراحی ندارند

- **Scoring:** §42 لیست Eventها را دارد ولی **هیچ Mode عدد ندارد**. §30 «Best Level Score» را Save می‌کند ولی Score تعریف نشده.
- **Bank Shot:** در Stats و Scoring هست، تعریف ندارد. «حداقل یک برخورد با دیوار قبل از برخورد با Target»؟
- **Multi Hit در برابر Combo:** §42 هر دو را جدا لیست می‌کند. فرقشان چیست؟
- **"Own Marble Exposed"** در جدول امتیازدهی AI (§33) — معیارش چیست؟
- **Reward:** §20 فیلد Reward دارد، §24 پول و XP را حذف می‌کند. پس Reward فقط Unlock ID است؟ باید صریح نوشته شود.
- **Save:** فرمت (JSON؟ Binary؟)، محل، و مهم‌تر — Versioning/Migration. Phase 6 است ولی تصمیمش ارزان‌تر است اگر الان گرفته شود.

---

## D. Content که وجود ندارد

- **Arena Layout:** هیچ نقشه، ابعاد یا موقعیت Launch Zone مشخص نیست. §37 می‌گوید «یک Arena استاندارد بساز» — کدام؟
- **Stage 3 تا 10:** §82 فقط عنوان دارد، نه طراحی. برای Vertical Slice به ۸ Level واقعی نیاز است: Target Count، چیدمان، Shot Limit، Objective، Secondary Objectiveها.
- **Holes Mode:** کل قوانینش یک پاراگراف است.

---

## E. تناقض‌ها و اشتباهات کوچک در خود سند

| # | مورد |
|---|---|
| E1 | جدول §11 ناقص است: Precision بدون Bounce، Sticky بدون Shot Power، Magnet بدون Bounce و Power |
| E2 | §17.2 Knockout: Tie-Break با «فاصله از مرکز» — ولی هدف Knockout بیرون انداختن است، نه کنترل مرکز. این معیارِ King of the Ring است. احتمالاً Copy-Paste |
| E3 | §64 «Win Stage» را به‌عنوان Secondary Objective لیست می‌کند، در حالی که Primary است |
| E4 | §34 درجه‌ها را Easy/Normal/Hard/Master می‌نامد، §63 همان‌ها را Beginner/Skilled/Expert. دو سیستم نام‌گذاری |
| E5 | §5.2 (هر Special یک نسخه) یعنی سقف طبیعی = ۵ Special + ۳ Standard. §28 می‌گوید Level می‌تواند سقف ۳ بگذارد — بد نیست، ولی سقف پیش‌فرض ۵ جایی نوشته نشده |
| E6 | §43 تا Combo x4 تعریف می‌کند و «4+» می‌گوید. سقف دارد یا نه؟ |

---

## F. Production — کاملاً غایب از سند

این‌ها Design نیستند ولی بدون‌شان تاریخ تحویل وجود ندارد:

- **Unity Version + Render Pipeline** (URP یا Built-in؟) — باید قفل شود
- **Input System:** پشتیبانی Controller در §8.1 عملاً یعنی New Input System. تصمیمش را بگیرید
- **تیم:** چند نفر؟ Solo؟ چه کسی Art می‌سازد؟
- **Timeline:** هفت Phase هست، هیچ تاریخ یا مدتی نیست
- **Art Pipeline:** Glass Shader تیله‌ها خریداری می‌شود یا ساخته؟ بودجه Asset؟
- **Audio:** Collision Sampleها از کجا؟ (۳ لایه × چند Variation)
- **Localization:** سند فارسی است، متن بازی انگلیسی. فارسی زبان Ship‌شدنی است؟ RTL هزینه‌ی واقعی دارد
- **Steam:** Achievementها، Cloud Save، صفحه Store — هیچ‌کدام در Scope نیست، ولی زمان می‌برند
- **اسم:** «Project Marbles» اسم کاری است یا نهایی؟
- **Playtest:** §72 معیار موفقیت دارد ولی نمی‌گوید چه کسی تست می‌کند و چند نفر
