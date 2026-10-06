# Project Marbles

بازی نوبتی مبتنی بر فیزیک — Turn-Based Physics Strategy / Marble Game.

| | |
|---|---|
| وضعیت | Phase 1 playable |
| موتور | Godot 4.7.2 · Forward+ · Jolt Physics · GDScript |
| پلتفرم | Windows x64 / Steam |

![preview](docs/preview.png)

## اجرا

پروژه را در Godot باز کنید و `F5` بزنید. راهنمای کامل کنترل و اینکه موقع بازی به چه چیزی نگاه کنید: **[docs/PROTOTYPE.md](docs/PROTOTYPE.md)**

```bash
"E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" --path "E:/Unity Games/Marbel"
```

کلیک در نوار آبی → نگه دار و به عقب بکش → رها کن.
`1`-`8` انتخاب تیله · `R` دوباره · `N` مرحله‌ی بعد · `F1` دیباگ

## تست

```bash
godot --headless --script res://tools/calibrate.gd   # §73 مسافت حرکت + تکرارپذیری
godot --headless --script res://tools/smoke.gd       # کل حلقه‌ی بازی، هر چهار مرحله
```

## مستندات

- **[PROTOTYPE](docs/PROTOTYPE.md)** — چه چیزی ساخته شد، چه چیزی نه، و چه باگ‌هایی حین ساخت پیدا شد
- [SPEC-PvE-v0.3](docs/SPEC-PvE-v0.3.md) — سند مرجع. اعداد فیزیک حالا اندازه‌گیری‌شده‌اند، نه حدسی
- [REVIEW-v0.2](docs/REVIEW-v0.2.md) — هر تغییر نسبت به v0.2 با دلیلش
- [OPEN-QUESTIONS](docs/OPEN-QUESTIONS.md) — بررسی GDD v0.1
- [archive GDD v0.1](docs/archive-GDD-PvE-v0.1.md)

## ساختار

```
main.tscn              صحنه‌ی ریشه — بقیه در کد ساخته می‌شود
scripts/game.gd        State machine، نوبت، Objective، Scoring
scripts/marble.gd      RigidBody3D، Settle Detection، State تیله
scripts/marble_data.gd آمار شش تیله (Damping از calibrate می‌آید)
scripts/levels.gd      چهار مرحله
scripts/hud.gd         UI
scripts/audio.gd       صدای برخورد، سنتزشده در Runtime
tools/                 تست‌های Headless
```

## تصمیم‌های باز

| # | موضوع | اثر |
|---|---|---|
| 1 | دیوار پیرامونی Arena (SPEC §9) — فعلاً «میز باز» فرض شده | Balance |
| 2 | Rubber در مراحل بدون Bumper بی‌استفاده است | Balance |
| 3 | Spike روی Shot Simulator مخصوص AI (SPEC §19) | Phase 4 را بلاک می‌کند |
| 4 | سختی مراحل حدسی است، باید بعد از Playtest تنظیم شود | Content |

## اولویت

> Core Physics First. Everything Else Second.
