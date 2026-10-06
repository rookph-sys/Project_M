# Project Marbles — Game Design Document (PvE v0.1)

| | |
|---|---|
| وضعیت | Pre-Production / Implementation Ready |
| پلتفرم اولیه | PC / Steam |
| موتور | Unity |
| تمرکز این نسخه | فقط PvE |
| ژانر | Turn-Based Physics Strategy / Marble Game |
| Presentation Direction | مینیمال، خوانا، سریع و تا حدی الهام‌گرفته از فلسفه‌ی بصری Balatro، بدون کپی مستقیم |

---

## 1. High Concept

Project Marbles یک بازی نوبتی مبتنی بر فیزیک است که در آن بازیکن قبل از هر Match مجموعه‌ای از تیله‌های خود را انتخاب می‌کند.

هر تیله یا:
- یک تیله ساده است.
- Stats متفاوت دارد.
- یا یک قابلیت مشخص و ساده دارد.

در هر نوبت بازیکن:
تیله را انتخاب می‌کند → محل ورود را تعیین می‌کند → نشانه می‌گیرد → قدرت را مشخص می‌کند → تیله را Flick می‌کند.

بعد از شلیک، تیله داخل زمین باقی می‌ماند و بخشی از وضعیت فیزیکی میدان می‌شود.
هر تیله در هر Round فقط یک بار به‌عنوان Shot اصلی استفاده می‌شود.

بنابراین بازیکن دائماً تصمیم می‌گیرد:
- کدام تیله را الان خرج کنم؟
- این تیله را از کجا وارد زمین کنم؟
- چطور با وضعیت فعلی میدان بیشترین استفاده را از آن ببرم؟

---

## 2. Design Pillars

### 2.1 Simple Input
بازیکن باید ظرف چند ثانیه کنترل بازی را بفهمد.

Core Input: `Select → Place → Aim → Flick`

هیچ Combo Input، Skill Bar یا کنترل پیچیده‌ای وجود ندارد.

### 2.2 Physics Creates Depth
عمق بازی نباید از تعداد زیاد Ruleها بیاید. عمق باید از این موارد ایجاد شود:
زاویه برخورد، قدرت Shot، Momentum، Bounce، Mass، موقعیت تیله‌ها، دیوارها، Holeها، وضعیت Arena، Ability تیله‌ها.

> قانون ساده است. نتیجه پیچیده است.

### 2.3 Marble Choice Matters
انتخاب تیله فقط Cosmetic نیست. Player Deck یا Marble Bag بخشی از Strategy است.

- Heavy Marble برای Knockback
- Rubber Marble برای Bank Shot
- Sticky Marble برای Positioning
- Magnet Marble برای تغییر وضعیت چند تیله

هیچ تیله‌ای نباید در تمام شرایط از Standard Marble بهتر باشد.

قاعده اصلی Balance:
```
Special ≠ Stronger
Special = Different Tool
```

### 2.4 Every Shot Should Feel Good
مهم‌ترین معیار کیفیت بازی: حتی بدون Progression، آیا شلیک کردن یک تیله لذت‌بخش است؟

Impact باید Feedback قوی داشته باشد: Collision Sound، Pitch Variation، Small Hit Stop، Trail، Particle، Camera Punch، Screen Shake محدود، Slow Motion برای ضربات مهم، Hit Marker بصری، Combo Feedback.

اگر خود Shot سرگرم‌کننده نباشد، Progression و Abilityها نباید برای پنهان کردن آن استفاده شوند.

---

## 3. Camera & Presentation

نمای اصلی بازی: **Top-Down / Slightly Angled 2.5D**. Arena تقریباً تمام صفحه را اشغال می‌کند.

پیشنهاد فنی: تیله‌ها و زمین واقعاً 3D باشند ولی Gameplay عمدتاً روی یک Plane انجام شود.

این روش اجازه می‌دهد:
- فیزیک طبیعی Sphere داشته باشیم.
- نورپردازی تیله‌ها بهتر باشد.
- Bounce و Collision جذاب‌تر دیده شود.
- در آینده Ramp یا Elevation محدود اضافه شود.

Camera نباید آزاد باشد. دوربین توسط بازی کنترل می‌شود. Player باید تمام اطلاعات لازم برای Shot را تقریباً همیشه ببیند.

---

## 4. Core Gameplay Loop

```
Choose Level
  ↓
Check Objective
  ↓
Build Marble Bag
  ↓
Enter Arena
  ↓
Select Marble
  ↓
Place Marble
  ↓
Aim
  ↓
Set Power
  ↓
Shoot
  ↓
Resolve Physics
  ↓
Resolve Abilities
  ↓
Check Objective
  ↓
Next Turn
  ↓
Win / Lose
  ↓
Reward / Progression
  ↓
Next Level
```

---

## 5. Marble Bag

هر بازیکن یک Marble Bag دارد. **Deck Size (نسخه اولیه): 8 Marbles**. Player قبل از Match این 8 تیله را انتخاب می‌کند.

### 5.1 Standard Marble
Standard Marble نقش Filler را دارد. بازیکن می‌تواند هر تعداد Slot خالی را با Standard Marble پر کند.

مثال: `Standard, Standard, Standard, Heavy, Rubber, Sticky, Magnet, Precision`

### 5.2 Special Marble Limit
در نسخه اولیه هر Special Marble فقط یک بار می‌تواند داخل Bag باشد (Heavy ×1، Rubber ×1، Magnet ×1)، اما Standard می‌تواند چند بار استفاده شود.

این قانون باعث می‌شود Balance ساده‌تر شود و بازیکن نتواند Deckهایی مثل `8× Heavy` یا `8× Magnet` بسازد.

### 5.3 Marble States
| State | توضیح |
|---|---|
| Reserve | هنوز استفاده نشده و داخل Bag است |
| Selected | برای Turn فعلی انتخاب شده |
| Placed | داخل Launch Zone قرار گرفته ولی هنوز Shot نشده |
| Active | Shot شده و در Arena قرار دارد |
| Exited | از Arena خارج شده |
| Destroyed | در Modeهایی که Destruction وجود دارد |

---

## 6. Turn Structure

1. **Turn Start** — Game State بررسی می‌شود. Objective Update می‌شود. Available Marbles نمایش داده می‌شوند.
2. **Marble Selection** — بازیکن یکی از تیله‌های Reserve را انتخاب می‌کند. قبل از انتخاب باید Marble Name، Ability، Mass، Bounce، Power را ببیند.
3. **Placement** — Launch Zone روشن می‌شود. Player تیله را فقط داخل محدوده مجاز قرار می‌دهد. Player نمی‌تواند Marble را آزادانه وسط Arena قرار دهد.
4. **Aim** — Player جهت Shot را مشخص می‌کند. Aim Line فقط مسیر ابتدایی را نشان می‌دهد. مسیر کامل Collision نباید به شکل دقیق نمایش داده شود. Player باید Skill یاد بگیرد.
5. **Power** — قدرت Shot بین 0 → 100% انتخاب می‌شود.
6. **Fire** — Player Shot را Commit می‌کند. بعد از Release، Shot قابل Cancel نیست.
7. **Physics Resolve** — Game منتظر می‌ماند تا همه Objects به حالت Sleep برسند یا Timeout اتفاق بیفتد.
   - پیشنهاد: **Physics Resolution Timeout: 8 Seconds**. اگر Object هنوز بعد از 8 ثانیه حرکت کند، Velocity به شکل نرم کاهش داده شود.
8. **Ability Resolution** — تمام Eventهای باقی‌مانده Resolve می‌شوند (Magnet Pull، Explosion، Score Trigger).
9. **Objective Evaluation** — Win / Lose Condition بررسی می‌شود.
10. **Turn End** — Marble به حالت Active منتقل می‌شود. Turn بعدی آغاز می‌شود.

---

## 7. Important Rule — Used Marbles

هر Marble فقط یک بار از Bag شلیک می‌شود. بعد از Shot داخل Arena باقی می‌ماند، اما Player در Turnهای بعد نمی‌تواند دوباره همان Marble را Flick کند.

این تصمیم سه مزیت دارد:
1. Matchها طول مشخص دارند.
2. Marble Bag اهمیت واقعی پیدا می‌کند.
3. Positioning تیله‌های قبلی بخشی از Strategy می‌شود.

Special Ability در آینده می‌تواند این قانون را بشکند (مثلاً Recall Marble یا Second Shot)، اما این‌ها فعلاً در نسخه اولیه وجود ندارند.

---

## 8. Shot Controls

### Mouse
| Input | Action |
|---|---|
| Left Click روی Marble در Bag | Select |
| Left Click داخل Launch Zone | Place |
| Click + Drag | Aim + Power |
| Release | Shoot |
| Right Click | Cancel Placement / Selection |

### 8.1 Controller
| Input | Action |
|---|---|
| Left Stick | Move Placement |
| A | Confirm |
| Right Stick | Aim |
| RT | Power / Shoot |
| B | Cancel |

---

## 9. Shot Formula

Power به صورت Normalized ذخیره می‌شود: `0.0 → 1.0`

```
FinalImpulse = BaseShotForce × Power × MarblePowerMultiplier
```

مثال:
- BaseShotForce: 10
- Standard Marble: PowerMultiplier = 1.0
- Heavy Marble: PowerMultiplier = 0.9
- Rubber Marble: PowerMultiplier = 1.05

اعداد نهایی باید در Prototype Tune شوند.

---

## 10. Marble Base Stats

تمام Marbleها این Data را دارند:
`ID, Name, Description, Icon, Material, Radius, Mass, Drag, Angular Drag, Friction, Bounciness, Shot Power Multiplier, Ability, Tags`

Tags می‌توانند شامل: `Standard, Heavy, Control, Bounce, Utility, Special` باشند.

---

## 11. Initial Marble Roster

برای اولین نسخه قابل‌بازی بیشتر از 6 Marble نسازیم.

| Marble | Mass | Bounce | Shot Power | ویژگی |
|---|---|---|---|---|
| **11.1 Standard** | 1.0 | 1.0 | 1.0 | Ability: None. Baseline تمام Balanceها |
| **11.2 Heavy** | 1.6 | 0.8 | 0.9 | Knockback قوی‌تر، حرکت خودش کمی کندتر |
| **11.3 Rubber** | 0.9 | 1.6 | 1.0 | Bounce زیاد از دیوار، مناسب Bank Shot |
| **11.4 Precision** | 0.8 | — | 0.8 | Aim Guide بلندتر، Power Control دقیق‌تر، برای Shotهای ظریف |
| **11.5 Sticky** | 1.0 | 0.3 | — | Friction: High. بعد از Collision سریع متوقف می‌شود. برای Block کردن مسیر یا Positioning |
| **11.6 Magnet** | 1.0 | — | — | وقتی کاملاً متوقف شد، یک Pulse کوتاه ایجاد می‌کند. تمام Marbleهای داخل Radius مشخص مقدار کمی به سمت آن کشیده می‌شوند. فقط یک بار Trigger می‌شود |

---

## 12. Ability Design Rules

- هر Marble حداکثر یک Ability اصلی دارد.
- Ability باید با یک جمله قابل توضیح باشد.
- Ability نباید Input جدید ایجاد کند.
- Ability عمدتاً باید Physics را تغییر دهد.
- Ability نباید بدون Counterplay باشد.
- Ability نباید Standard Marble را بی‌استفاده کند.

---

## 13. Ability Event System

Ability Framework باید Event-Based باشد.

Supported Events:
`OnPlaced, OnShot, OnFirstCollision, OnCollision, OnStop, OnExitArena, OnTurnEnd, OnRoundEnd`

مثال — Magnet Marble:
```
OnStop → PullNearbyMarbles()
```

در نتیجه Abilityهای آینده بدون تغییر Core Gameplay قابل اضافه شدن هستند.

---

## 14. PvE Structure

PvE از دو بخش اصلی تشکیل می‌شود:
- **Campaign** — مراحل طراحی‌شده و Progression اصلی.
- **Challenge Mode** — مراحل کوتاه با Ruleهای مشخص. بعداً از Campaign Content استفاده مجدد می‌کند.

---

## 15. Campaign Structure

| Chapter | عنوان |
|---|---|
| Chapter 1 | Learn the Game |
| Chapter 2 | Angles & Bounce |
| Chapter 3 | Power & Weight |
| Chapter 4 | Special Marbles |
| Chapter 5 | Advanced Challenges |

برای Vertical Slice فقط Chapter 1 کافی است.

---

## 16. Recommended Full PvE Content Target

نسخه کامل اولیه: 5 Chapters × 8 Stages = **40 Stages**
Vertical Slice: **8–10 Stage** کافی است.

---

## 17. PvE Game Modes

پنج Mode برای سیستم طراحی می‌شوند، اما در اولین Build فقط سه Mode پیاده‌سازی شوند.

### 17.1 Ringer
اولین Mode برای پیاده‌سازی. Target Marbleها داخل Ring قرار دارند.
هدف: تیله‌های مشخص را از Ring خارج کن.
- Objective: Knock 6 Red Marbles out of the Ring.
- Shot Limit: 8
- Secondary Objective: Finish using 6 Shots or fewer.

### 17.2 Knockout
Player در مقابل AI بازی می‌کند. هر طرف Marble Bag خودش را دارد.
هدف: تیله‌های حریف را از Arena خارج کن. هر Marble بیرون‌رفته: 1 Point.
بعد از تمام شدن Shotهای هر دو طرف، Player با بیشترین Score برنده است.
در Tie: مقایسه Total Remaining Marble Distance From Center — کسی که تیله‌هایش به مرکز نزدیک‌تر هستند برنده می‌شود.

### 17.3 Holes
Arena دارای Hole است. هدف: Marbleهای مشخص را داخل Hole قرار بده (مثلاً Sink 3 Target Marbles). بازیکن Marble خودش را Shot می‌کند تا Target Marbleها را جابه‌جا کند.

### 17.4 King of the Ring
اولویت دوم Development. Player و AI Marbleهای خود را وارد Arena می‌کنند. در پایان Match هر Marble داخل Ring امتیاز دارد، هر Marble خارج Ring حذف می‌شود. هدف: Control کردن مرکز Arena.

### 17.5 Trick Shot
Puzzle-Based Mode. مثلاً:
- Hit 3 Targets with one Shot.
- Hit the Red Marble after bouncing from 2 Walls.
- Do not touch the Black Marble.
- Finish in 2 Shots.

این Mode برای تولید Content کم‌هزینه بسیار مهم است.

---

## 18. MVP Game Modes

برای اولین نسخه: **Ringer، Holes، Knockout vs AI**
King of the Ring و Trick Shot بعد از اثبات Core Gameplay اضافه شوند.

---

## 19. Objective System

Objectiveها نباید Hardcoded داخل Level باشند. Objective System باید Data-Driven باشد.

Objective Types:
`KnockOutTarget, KnockOutCount, SinkTarget, SinkCount, ReachScore, CompleteWithinShots, KeepMarbleInsideArena, AvoidTarget, HitTarget, ChainCollision, BeatAI`

---

## 20. Level Definition

هر Level باید از Data ساخته شود:
`Level ID, Level Name, Mode, Arena, Player Shot Limit, Enemy Configuration, Available Launch Zones, Target Marbles, Obstacles, Objectives, Secondary Objectives, Reward, Unlock Requirements`

---

## 21. Example Level — Level 01 "First Flick"

- Mode: Ringer
- Bag: 8 Standard Marble
- Target: 4 Red Marble
- Objective: Knock 2 Red Marbles outside Ring
- Shot Limit: 8
- No Special Marble. No Obstacle.
- Reward: Unlock Deck Builder

---

## 22. Example Level 02

- Mode: Ringer
- Targets: 6
- Objective: Knock 4 out
- Obstacle: One Wall
- Reward: Precision Marble Trial

---

## 23. Example Marble Trial

Player Marble Bag برای این Stage موقتاً شامل Precision Marble می‌شود.
Objective: Complete level using Precision Marble.
اگر Player موفق شود: Precision Marble Unlocked — از آن لحظه Marble وارد Collection دائمی بازیکن می‌شود.

---

## 24. Progression Philosophy

Progression نباید Grind-Based باشد. فعلاً موارد زیر وجود ندارند:
XP Level، Loot Box، Crafting، Marble Upgrade، Random Drop، Currency Grind.

هدف: Player با یادگیری Gameplay تیله جدید Unlock کند.

---

## 25. Marble Unlock Flow

```
Discover → Trial → Complete Challenge → Unlock
```

مثال: Player در Level 5 برای اولین بار Heavy Marble را می‌بیند. Level بعد: Heavy Marble Trial. Player باید Knock 3 Targets Out کند. بعد: Heavy Marble permanently unlocked.

---

## 26. Collection Screen

تمام Marbleهای Game در Collection دیده می‌شوند.
- Locked Marble: Silhouette، Name ممکن است مخفی باشد.
- Unlocked Marble: 3D Preview، Name، Ability، Stats، Usage Statistics.

---

## 27. Stats Display

برای جلوگیری از شلوغی، Player اعداد فیزیکی واقعی نمی‌بیند. UI فقط Bar نمایش می‌دهد:

```
Power    ●●●○○
Weight   ●●●●○
Bounce   ●●○○○
Control  ●●●○○
```

---

## 28. Deck Builder

قبل از Stage بازیکن وارد Deck Builder می‌شود. 8 Slot نمایش داده می‌شود:

```
1 — Standard
2 — Standard
3 — Standard
4 — Heavy
5 — Rubber
6 — Precision
7 — Sticky
8 — Magnet
```

Level ممکن است محدودیت داشته باشد (مثلاً Special Marble Maximum: 3، یا Heavy Marble Disabled)، اما استفاده از محدودیت‌ها باید بسیار کم باشد.

---

## 29. Recommended Loadout

Level می‌تواند Suggested Marble نمایش دهد (مثلاً `Recommended: Rubber Marble`)، ولی Game نباید Player را مجبور کند.

---

## 30. Save System

Save Data باید حداقل شامل موارد زیر باشد:
Unlocked Marble IDs، Completed Levels، Best Level Score، Objectives Completed، Current Chapter، Saved Loadouts، Gameplay Statistics، Settings.

---

## 31. Gameplay Statistics

از ابتدا این موارد Track شوند:
Shots Fired، Total Playtime، Targets Hit، Marbles Knocked Out، Marbles Sunk، Bank Shots، Perfect Shots، Wins، Losses، Marble Usage Count.

این اطلاعات بعداً برای Achievements، Challenges و Balancing استفاده می‌شود.

---

## 32. AI System

AI نباید Cheat کند. AI باید همان Shot Rules بازیکن را داشته باشد.

```
Analyze Board → Select Marble → Select Placement → Select Target
  → Calculate Aim → Calculate Power → Apply Difficulty Error → Shoot
```

---

## 33. AI Shot Evaluation

AI چند Shot Candidate تولید می‌کند، مثلاً 32 Candidate Directions × 3 Power Levels.
هر Shot از نظر Goal امتیاز می‌گیرد. مثلاً در Knockout:

| Event | Score |
|---|---|
| Enemy Knocked Out | +100 |
| Enemy Moved Toward Edge | +30 |
| Own Marble Knocked Out | -100 |
| Own Marble Exposed | -20 |
| Center Control | +10 |

Candidate با بیشترین Score انتخاب می‌شود.

---

## 34. AI Difficulty

| Difficulty | Candidate Count | Aim Error | Power Error |
|---|---|---|---|
| Easy | کم | زیاد | زیاد |
| Normal | متوسط | متوسط | — |
| Hard | زیاد | کم | — |
| Master | Shot Simulation بیشتر | تقریباً بدون Error | — |

Master همچنان از Ruleهای Player استفاده می‌کند.

---

## 35. AI Technical Recommendation

بهترین معماری: یک Physics Scene جدا برای Shot Simulation. AI می‌تواند Candidate Shot را بدون نمایش روی Board Simulation کند و بعد نتیجه را Evaluate کند.

این سیستم بعداً برای Aim Prediction، Replay Analysis و Tutorial هم قابل استفاده است.

---

## 36. Arena System

Arena شامل: Boundary، Launch Zone، Ring، Hole، Wall، Obstacle، Trigger Zone، Decoration.

Game Logic نباید به Art Arena وابسته باشد.

---

## 37. Arena Scale

در Prototype یک Arena استاندارد ساخته شود. تمام Balance اولیه روی همان Arena انجام شود. بعد از تثبیت Gameplay، Arenaهای جدید ساخته شوند.

---

## 38. Launch Zones

Player Marble را نمی‌تواند هر جایی Spawn کند. هر Stage یک یا چند Launch Zone دارد.

انواع: `Line, Arc, Rectangle, Point`

برای Ringer معمولاً Arc یا Line در کنار Arena مناسب است.

---

## 39. Collision Rules

Marble می‌تواند برخورد کند با: Marble، Wall، Obstacle، Target، Hole Trigger، Arena Boundary.

Collision Layerها از ابتدا جدا طراحی شوند.

---

## 40. Out Of Bounds

Marble وقتی کاملاً از Arena Boundary عبور کند:
- State: Exited
- Velocity: Zero
- Collider: Disabled

اگر Marble متعلق به Player باشد، به‌عنوان Marble Lost ثبت می‌شود. اگر Target باشد، Objective Update می‌شود.

---

## 41. Hole Behavior

اگر مرکز Marble وارد Hole Trigger شود:
- Input Physics متوقف می‌شود.
- Marble Animation کوتاه سقوط اجرا می‌شود.
- State: Sunk
- Collider: Disabled
- Objective Update می‌شود.

---

## 42. Scoring System

Scoring باید Mode-Specific باشد، اما Base Events مشترک باشند:
`Target Hit, Target Out, Target Sunk, Multi Hit, Bank Shot, Perfect Shot, Combo`

هر Mode مشخص می‌کند کدام Event چند Score دارد.

---

## 43. Combo

Combo فقط Presentation نیست. اگر یک Shot چند اتفاق موفق ایجاد کند:
- 2 Hits → Combo x2
- 3 Hits → Combo x3
- 4+ Hits → Combo x4

فعلاً Combo روی Win Condition اثر مستقیم ندارد؛ برای Score و Feedback استفاده می‌شود.

---

## 44. Perfect Shot

اگر Shot مستقیماً Objective اصلی را کامل کند (مثلاً آخرین Target را Knock Out کند)، Perfect Shot Trigger می‌شود.

Presentation: Slow Motion کوتاه، Camera Zoom، Large Text، Unique Sound.

---

## 45. Physics Feel

Physics نباید کاملاً Simulation-Accurate باشد. هدف: **Readable + Predictable + Satisfying**.

اگر Real Physics باعث شود Game Feel بد شود، Physics باید Tune شود.

مهم‌ترین ویژگی: بازیکن باید بعد از چند دقیقه بتواند رابطه `Power → Distance` و `Angle → Collision` را یاد بگیرد.

---

## 46. Aim Assist

Aim Assist باید محدود باشد. Player:
- Initial Direction را می‌بیند.
- ممکن است First Collision Point را ببیند.
- اما Bounce کامل و Chain Prediction نمایش داده نمی‌شود.

Precision Marble می‌تواند Aim Guide بهتری داشته باشد.

---

## 47. Input Forgiveness

برای جلوگیری از Frustration:
- Minimum Shot Power داشته باشیم.
- Dead Zone در Drag وجود داشته باشد.
- Minor Aim Snapping فقط در Tutorial فعال باشد.

---

## 48. Tutorial

Tutorial باید داخل Gameplay باشد، نه یک صفحه متن.

1. Select Marble
2. Place
3. Aim
4. Power
5. Hit Target
6. Knock Target Out

در کمتر از 5 دقیقه Core Game باید آموزش داده شود.

---

## 49. UI Layout

| ناحیه | محتوا |
|---|---|
| Top | Current Objective، Shots Remaining، Score |
| Bottom | Marble Bag، Marble Info |
| Center | Arena |
| Side | Optional Secondary Objective |

---

## 50. Marble Selection UI

Marbleهای Reserve پایین صفحه قرار دارند.
- Selected Marble: کمی بزرگ‌تر می‌شود، Glow محدود دارد، Ability Text نمایش داده می‌شود.
- Used Marbleها: Gray Out می‌شوند.

---

## 51. Visual Direction

Presentation باید Clean، Dark، High Contrast و Tactile باشد.

پیشنهاد: Dark Table Surface، Colorful Glass Marbles، Large Typography، Simple UI Panels، Very Subtle CRT Distortion، Light Grain، Glow محدود.

---

## 52. Balatro Influence

**گرفته می‌شود:** Strong Feedback، Simple Screen Layout، Large Numbers، Fast Transitions، Readable Icons، High Contrast، Juicy Reward Moments.

**Copy نمی‌شود:** Poker UI، Exact Color Palette، Card Layout، Fonts، CRT intensity، Joker presentation.

---

## 53. Audio

Audio یکی از مهم‌ترین قسمت‌های Game Feel است. باید چندین Collision Sample داشته باشیم:
- برخورد آرام: Light Click
- برخورد متوسط: Clack
- برخورد شدید: Hard Crack

Pitch و Volume بر اساس Collision Velocity تغییر کند.

---

## 54. Music

Music باید Background باشد، نه Dominant.
- در Shot: Music Duck بسیار کوتاه می‌تواند Impact را بهتر کند.
- در Perfect Shot: Music Hit یا Sting کوتاه.

---

## 55. Feedback Priority

| Event | Feedback |
|---|---|
| Small Hit | Audio + Tiny Particle |
| Important Hit | Audio + Particle + Camera Punch |
| Knockout | Audio + Screen Shake + Text |
| Level Complete | Freeze + Celebration |

---

## 56. Game State Machine

```
Loading → PreMatch → TurnStart → SelectingMarble → PlacingMarble
  → Aiming → ShotCommitted → PhysicsResolving → AbilityResolving
  → ObjectiveResolving → TurnEnd → Victory / Defeat → Reward → Exit
```

هیچ سیستم نباید مستقیماً State را دور بزند.

---

## 57. Core Runtime Components

| Component | مسئولیت |
|---|---|
| GameFlowController | State Machine اصلی |
| TurnController | Turn Ownership و Flow |
| ShotController | Aim / Power / Fire |
| MarbleController | Runtime Marble State |
| MarbleDefinition | Static Marble Data |
| AbilityController | Ability Event Handling |
| PhysicsResolver | تشخیص پایان Simulation |
| ArenaController | Arena Objects |
| ObjectiveManager | Win / Lose / Objective |
| ScoreManager | Scoring |
| AIController | PvE Opponent |
| CollectionManager | Unlocked Marbleها |
| LoadoutManager | Marble Bag |
| ProgressionManager | Level Unlock |
| SaveManager | Persistence |

---

## 58. MarbleDefinition

پیشنهاد می‌شود ScriptableObject باشد.

```
Id
DisplayName
Description
Icon
Prefab
Material
Mass
Radius
Friction
Bounciness
Drag
AngularDrag
ShotPowerMultiplier
AbilityId
Tags
```

---

## 59. LevelDefinition

ScriptableObject:

```
LevelId
DisplayName
ModeId
ArenaId

ShotLimit

PlayerLoadoutRules
EnemyConfig

LaunchZones

TargetConfiguration
ObstacleConfiguration

PrimaryObjectives
SecondaryObjectives

Reward
UnlockRequirements
```

---

## 60. Shot Command

از همین الان Input مستقیم Physics را اجرا نکند. ابتدا یک ShotCommand ساخته شود:

```
ActorId
MarbleId
SpawnPosition
Direction
Power
```

بعد Gameplay این Command را Execute کند.

دلیل این تصمیم: در آینده همین Command می‌تواند از Online Player دریافت شود. بنابراین PvE Code نیاز به Rewrite اساسی نخواهد داشت.

---

## 61. Future Online Compatibility

فعلاً Networking ساخته نمی‌شود، اما معماری باید این موارد را از الان رعایت کند:
- Player Input مستقیم Game State را تغییر ندهد.
- همه Shotها Command باشند.
- هر Marble OwnerId داشته باشد.
- TurnController مستقل از Human/AI باشد.
- Game Mode Logic مستقل از Local Input باشد.
- Physics Resolution یک مرحله مشخص داشته باشد.

این کار بعداً Host-Based Multiplayer را بسیار ساده‌تر می‌کند.

---

## 62. Player Actor Interface

Player و AI باید از دید GameFlow مشابه باشند.

```
IGameActor
  SelectMarble()
  ChoosePlacement()
  ChooseShot()
  SubmitShotCommand()
```

HumanController و AIController هر دو این Interface را اجرا می‌کنند.

---

## 63. PvE Enemy Design

در فاز اول Enemy Character نمی‌خواهیم. AI فقط Difficulty Profile دارد: Beginner، Skilled، Expert.

بعداً Personality اضافه می‌شود: Aggressive AI، Defensive AI، Trick Shot AI.

---

## 64. Secondary Objectives

هر Stage حداکثر دو Secondary Objective دارد. مثلاً:
- Win Stage
- Finish within 5 Shots
- Use no Standard Marble

Secondary Objective برای Replayability است، نه برای جلوگیری از Progression. Player برای باز کردن Level بعد فقط باید Primary Objective را کامل کند.

---

## 65. Stage Rating

Maximum 3 Medals:
- Medal 1: Complete Stage
- Medal 2: Complete Secondary Objective 1
- Medal 3: Complete Secondary Objective 2

Medalها برای Cosmetics، Achievements و Completion استفاده می‌شوند. Gameplay Marble اصلی پشت Medal Grind قفل نشود.

---

## 66. Unlock System

Gameplay Marbleها عمدتاً با Campaign Progress و Marble Trial Unlock شوند.
Cosmeticها می‌توانند با Medals، Challenges و Achievements باز شوند.

---

## 67. Cosmetics

فعلاً Gameplay System محسوب نمی‌شود. اما Data Structure Marble از ابتدا **Gameplay Type** و **Visual Skin** را جدا کند.

مثلاً Heavy Marble یک Gameplay Type است؛ Black Iron، Galaxy و Blood Glass فقط Skin هستند. Skin هیچ تأثیری بر Stats ندارد.

---

## 68. Fail Conditions

Stage می‌تواند Fail شود اگر Shots Remaining = 0 و Objective کامل نشده، یا AI Win Condition کامل شود.

Player می‌تواند Retry، Change Loadout یا Exit را انتخاب کند. Retry باید تقریباً Instant باشد.

---

## 69. Retry Philosophy

Physics Game شامل Trial & Error است. بنابراین Retry نباید Punishment داشته باشد:
No Energy، No Lives، No Currency Cost.

Restart زیر 2 ثانیه هدف‌گذاری شود.

---

## 70. Pause

Pause Menu: Resume، Restart، Objective، Controls، Settings، Exit Level.

---

## 71. Accessibility

از ابتدا: Aim Line Visibility Option، Screen Shake Slider، Slow Motion Toggle، Colorblind-Friendly Target Icons، Controller Support، Text Scaling.

Physics Speed accessibility بعداً بررسی شود.

---

## 72. Prototype Success Criteria

قبل از اضافه کردن Progression باید این Test پاس شود:
- یک Arena
- Standard Marble
- 10 Target Marble
- بدون Reward
- بدون Ability

اگر تست‌کننده حاضر باشد 10 دقیقه فقط Shot بزند و Experiment کند، Core Physics موفق است. اگر نه، Feature بیشتری اضافه نمی‌کنیم و Physics اصلاح می‌شود.

---

## 73. First Playable Build

اولین Build فقط شامل: 1 Arena، 1 Marble Type، Ringer، 8 Shots، Basic Objective، Aim، Power، Collision، Out Of Bounds، Win، Lose، Restart.

هیچ Collection یا Progression هنوز ساخته نمی‌شود.

---

## 74. Development Phase 1 — Core Physics

Deliverables: Marble Rigidbody، Arena Collision، Launch Zone، Aim Input، Power Input، Shot Command، Physics Resolve، Out Of Bounds، Basic Camera، Basic Audio.

هدف: اثبات Game Feel.

---

## 75. Development Phase 2 — Match Framework

Deliverables: Game State Machine، TurnController، Marble Bag، Marble Selection، Shot Limit، Objective Manager، Win / Lose، Restart.

---

## 76. Development Phase 3 — Marble Framework

Deliverables: MarbleDefinition، Standard، Heavy، Rubber، Precision، Sticky، Ability Event System، Magnet.

---

## 77. Development Phase 4 — PvE Modes

Order: Ringer → Holes → Knockout.
در این مرحله Game Mode Logic Data-Driven می‌شود.

---

## 78. Development Phase 5 — AI

Deliverables: AI Actor، Candidate Generation، Shot Evaluation، Difficulty Profiles، Physics Simulation Prediction، Knockout AI.

---

## 79. Development Phase 6 — Progression

Deliverables: Campaign Map، Level Unlock، Collection، Deck Builder، Marble Trial، Save System، Medals.

---

## 80. Development Phase 7 — Presentation

Deliverables: Final UI Direction، Impact Effects، Camera Feedback، Audio Pass، Transitions، Victory، Defeat، Marble Collection Presentation.

---

## 81. Vertical Slice Definition

Vertical Slice زمانی کامل است که شامل این موارد باشد:
10 PvE Levels، 3 Game Modes، 6 Marble Types، 1 Complete Chapter، 1 AI Opponent، Marble Collection، Deck Builder، Unlock System، Save/Load، Final-ish UI، Basic Audio/VFX.

---

## 82. Vertical Slice Content Example

| Stage | محتوا |
|---|---|
| 1 | Basic Ringer |
| 2 | Ringer + Walls |
| 3 | Precision Trial |
| 4 | Holes Introduction |
| 5 | Heavy Trial |
| 6 | Ringer Advanced |
| 7 | Rubber Trial |
| 8 | Knockout Tutorial |
| 9 | AI Duel |
| 10 | Chapter Final Challenge |

---

## 83. Scope Restrictions

برای جلوگیری از Scope Creep در این مرحله ساخته نمی‌شوند:
Online Multiplayer، PvP Draft، Dedicated Server، Matchmaking، Ranked، Daily Challenge، Marble Crafting، Marble Upgrade Tree، Loot Boxes، Currencies، Battle Pass، Procedural Campaign، Large Roguelike Meta System، Character System، Narrative Campaign.

---

## 84. Primary Balance Rules

- Standard Marble همیشه باید Viable باشد.
- Special Marble نباید Direct Upgrade باشد.
- Ability باید Counter یا Weakness داشته باشد.
- Powerful Marble باید Trade-Off داشته باشد.
- Randomness نباید نتیجه Skillful Shot را خراب کند.
- Player باید بتواند رفتار Physics را یاد بگیرد.

---

## 85. Randomness

در Core Physics عمداً Randomness نداشته باشیم. یک Shot با Marble، Position، Direction و Power یکسان باید تقریباً نتیجه یکسان بدهد.

Randomness بعداً فقط می‌تواند در Level Selection، Reward Presentation و PvP Draft باشد — نه Collision.

---

## 86. Key Metrics During Testing

در Playtest ثبت شود:
Average Level Duration، Average Shots Used، Retry Rate، Win Rate، Marble Pick Rate، Marble Win Rate، Average Shot Setup Time، Number of Bank Shots، Number of Multi Hits، Quit During Level.

اگر Marble خاصی Pick Rate بسیار بالا داشته باشد، احتمالاً Overpowered یا بیش از حد عمومی است.

---

## 87. Target Match Duration

- Solo Challenge: 2–5 Minutes
- AI Match: 5–8 Minutes
- Stage نباید معمولاً بیشتر از 10 دقیقه طول بکشد.

هدف بازی: Short Sessions، Fast Retry، "One More Match".

---

## 88. Target Turn Duration

Player باید معمولاً ظرف 5–15 Seconds Shot را آماده کند. هدف این نیست که هر Shot تبدیل به Puzzle چند دقیقه‌ای شود.

---

## 89. Core Emotional Loop

```
I see a shot.
  ↓
Maybe this will work.
  ↓
Flick.
  ↓
CLACK.
  ↓
Unexpected chain reaction.
  ↓
That was awesome.
  ↓
I want another shot.
```

این Loop از هر Progression System مهم‌تر است.

---

## 90. Final PvE Product Identity

Project Marbles نباید به‌عنوان "Marble Simulator" طراحی شود.

هویت درست آن:
> A turn-based physics strategy game built around collecting, choosing and flicking unique marbles.

سادگی کنترل باید شبیه یک Toy باشد. عمق تصمیم‌گیری باید شبیه Strategy Game باشد. و هر Match باید آن‌قدر کوتاه باشد که بازیکن فوراً بخواهد دوباره بازی کند.

---

## 91. Current Design Locks

| مورد | قفل |
|---|---|
| Camera | Top-down 2.5D |
| Physics | 3D sphere physics constrained mostly to a flat arena |
| Bag Size | 8 |
| Special Marble | Maximum one copy per type |
| Standard Marble | Unlimited filler |
| Shot Rule | Every marble can be launched once per match/round |
| Used Marble | Remains physically inside Arena |
| Core Input | Select → Place → Aim → Power → Release |
| PvE Loadout | Player freely builds Bag from unlocked collection |
| Initial Marble Count | 6 |
| Initial Modes | Ringer → Holes → Knockout |
| Progression | Campaign + Marble Trials |
| Unlock | No XP grind / no random loot |
| Retry | Instant and free |
| Online | Not implemented now, but ShotCommand architecture preserved |

---

## 92. Development Priority

اگر تیم همین امروز Development را شروع کند، اولین هدف فقط باید این باشد:

> یک Standard Marble را داخل یک Arena قرار بدهیم، با Mouse Aim و Power بدهیم، آن را به چند Marble دیگر بزنیم و برخورد آن‌قدر خوب باشد که بدون هیچ Feature دیگری سرگرم‌کننده باشد.

تا زمانی که این بخش جواب نداده، Deck / AI / Progression / Campaign / Special Marble نباید اولویت اصلی شوند.

**Core Physics First. Everything Else Second.**
