# Project Marbles

بازی نوبتی مبتنی بر فیزیک — Turn-Based Physics Strategy / Marble Game.

| | |
|---|---|
| وضعیت | Pre-Production / Implementation Baseline |
| موتور | Godot 4.x · Forward+ · Jolt Physics · C# |
| پلتفرم | Windows x64 / Steam |
| تمرکز نسخه فعلی | PvE — Vertical Slice (۱۰ Level، ۳ Mode، ۶ Marble) |

## مستندات

- **[SPEC-PvE-v0.3](docs/SPEC-PvE-v0.3.md)** — سند مرجع فعلی. Godot، با اعداد اصلاح‌شده.
- [REVIEW-v0.2](docs/REVIEW-v0.2.md) — هر تغییر نسبت به v0.2 با دلیلش
- [OPEN-QUESTIONS](docs/OPEN-QUESTIONS.md) — بررسی GDD v0.1 (بیشترش در v0.2 و v0.3 حل شده)
- [archive-GDD-PvE-v0.1](docs/archive-GDD-PvE-v0.1.md) — سند طراحی اولیه

## تصمیم‌های باز

| # | موضوع | اثر |
|---|---|---|
| 1 | دیوار پیرامونی Arena دارد یا نه (SPEC §9) | **Phase 1 را بلاک می‌کند** |
| 2 | Spike روی Shot Simulator مخصوص AI (SPEC §19) | Phase 4 — ولی Spike در هفته‌ی اول |
| 3 | Rubber Marble در ۸ Level از ۱۰ بی‌استفاده است | Balance |
| 4 | Level 07 — Magnet با Objective خودش می‌جنگد | Level Design |
| 5 | نسخه‌ی دقیق Godot | باید Pin شود |

## اولویت فعلی

> Core Physics First. Everything Else Second.

یک Standard Marble داخل یک Arena، با Mouse Aim و Power، برخورد با چند Marble دیگر — آن‌قدر خوب که بدون هیچ Feature دیگری سرگرم‌کننده باشد.
