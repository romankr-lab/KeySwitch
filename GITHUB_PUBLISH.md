# Публікація KeySwitch на GitHub

## Підготовка (вже зроблено)

- [x] `.gitignore` — ігноруються `build/`, `*.dmg`, `.DS_Store`, Xcode/SPM артефакти
- [x] `README.md` — опис проєкту, встановлення, використання
- [x] `LICENSE` — MIT

## Кроки публікації

### 1. Замінити плейсхолдер у README

Відкрийте `README.md` і замініть **romankr-lab** на ваш логін GitHub у посиланнях:

- `https://github.com/romankr-lab/KeySwitch/releases`
- `git clone https://github.com/romankr-lab/KeySwitch.git`

### 2. Ініціалізувати Git і перший коміт

У корені проєкту виконайте:

```bash
cd /Users/roman/Projects/KeySwitch

# Ініціалізація репозиторію
git init

# Додати всі файли (згідно .gitignore)
git add .
git status   # перевірити, що немає build/, *.dmg тощо

# Перший коміт
git commit -m "Initial commit: KeySwitch menu bar app (clipboard + layout transform)"
```

### 3. Створити репозиторій на GitHub

1. Зайдіть на [github.com](https://github.com) і увійдіть.
2. **New repository** (або **+** → New repository).
3. **Repository name:** `KeySwitch`.
4. Опис (опційно): *macOS menu bar app: clipboard history and keyboard layout text transformation*.
5. **Public.**
6. **Не** ставлячи галочки "Add a README" / "Add .gitignore" (вони вже в проєкті).
7. Натисніть **Create repository**.

### 4. Підключити remote і запушити

На сторінці нового репозиторію GitHub скопіюйте URL (наприклад `https://github.com/romankr-lab/KeySwitch.git`) і виконайте:

```bash
git remote add origin https://github.com/romankr-lab/KeySwitch.git
git branch -M main
git push -u origin main
```

Якщо використовуєте SSH:

```bash
git remote add origin git@github.com:romankr-lab/KeySwitch.git
git branch -M main
git push -u origin main
```

### 5. (Опційно) Перший реліз

1. Зберіть DMG: `./build_and_package.sh`
2. На GitHub: **Releases** → **Create a new release**.
3. **Tag:** наприклад `v1.0.0` (Create new tag).
4. **Release title:** `v1.0.0` або `KeySwitch 1.0`.
5. В **Description** можна вставити короткий список змін з README.
6. Перетягніть `KeySwitch.dmg` у блок для завантажень.
7. **Publish release.**

Після цього посилання на завантаження в README будуть працювати (після заміни romankr-lab).

## Що не потрапляє в Git (завдяки .gitignore)

- Папка `build/`
- Файли `KeySwitch.dmg`, `KeySwitch.zip`
- `xcuserdata/`, `.DS_Store`
- Залежності SPM у `build/` (Xcode підтягне їх при збірці)

Готово: проєкт оформлений під повноцінний продукт і готовий до публікації на GitHub.
