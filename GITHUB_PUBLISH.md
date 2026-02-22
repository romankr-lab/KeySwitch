# Publishing KeySwitch on GitHub

## Preparation (already done)

- [x] `.gitignore` — ignores `build/`, `*.dmg`, `.DS_Store`, Xcode/SPM artifacts
- [x] `README.md` — project description, installation, usage
- [x] `LICENSE` — MIT

## Publishing steps

### 1. Replace placeholder in README (if needed)

If you use a different GitHub username, update the links in `README.md`:

- `https://github.com/romankr-lab/KeySwitch/releases`
- `git clone https://github.com/romankr-lab/KeySwitch.git`

### 2. Initialize Git and make the first commit

In the project root:

```bash
cd /path/to/KeySwitch

# Initialize repository
git init

# Add all files (respecting .gitignore)
git add .
git status   # confirm no build/, *.dmg etc.

# First commit
git commit -m "Initial commit: KeySwitch menu bar app (clipboard + layout transform)"
```

### 3. Create the repository on GitHub

1. Go to [github.com](https://github.com) and sign in.
2. **New repository** (or **+** → New repository).
3. **Repository name:** `KeySwitch`.
4. Description (optional): *macOS menu bar app: clipboard history and keyboard layout text transformation*.
5. **Public.**
6. **Do not** add a README or .gitignore (they already exist in the project).
7. Click **Create repository**.

### 4. Add remote and push

On the new repository page, copy the URL (e.g. `https://github.com/romankr-lab/KeySwitch.git`) and run:

```bash
git remote add origin https://github.com/romankr-lab/KeySwitch.git
git branch -M main
git push -u origin main
```

If you use SSH:

```bash
git remote add origin git@github.com:romankr-lab/KeySwitch.git
git branch -M main
git push -u origin main
```

### 5. (Optional) First release

1. Build the DMG: `./build_and_package.sh`
2. On GitHub: **Releases** → **Create a new release**.
3. **Tag:** e.g. `v1.0.0` (create new tag).
4. **Release title:** `v1.0.0` or `KeySwitch 1.0`.
5. In **Description**, you can paste a short changelog or feature list from the README.
6. Drag `KeySwitch.dmg` into the attachments area.
7. **Publish release.**

After that, the download link in the README will work.

## What is not committed (thanks to .gitignore)

- `build/` directory
- `KeySwitch.dmg`, `KeySwitch.zip`
- `xcuserdata/`, `.DS_Store`
- SPM checkouts under `build/` (Xcode will fetch them on build)

Done: the project is ready to be published on GitHub.
