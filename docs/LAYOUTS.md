## 📸 Layouts

### Classic List *(default)*
A plain vertical/list layout — lightest on GPU, good for weaker hardware or minimal setups.

![Classic List](../assets/screenshots/classic.jpg)

---

### Bottom Dock 
A sheared, parallelogram card deck along the bottom of the screen, uniform card height, with the focused card scaled up and outlined in your accent color.

![Bottom Dock](../assets/screenshots/bottom-dock.jpg)

---

### Coverflow Family
Cards fan out in 3D-style perspective around the focused item, classic "coverflow" browsing feel.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Coverflow** | Classic 3D coverflow with background blur | ![Coverflow](../assets/screenshots/coverflow.jpg) |
| **Coverflow Clear** | Coverflow without background blur — use this if your compositor/GPU can't keep blur smooth | ![Coverflow Clear](../assets/screenshots/coverflow-clear.jpg) |
| **Coverflow Minimal** | Coverflow without on-screen widgets (clock/info) layered in | ![Coverflow Minimal](../assets/screenshots/coverflow-minimal.jpg) |

---

### Floating Family

#### Floating (with widgets & reflections)
Features a tiered, 3D floating cloud effect with an ultra-smooth background blur and a glassmorphic Date & Time overlay in the top center.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Floating** | Blurred background with glassmorphic date/time overlay, reflections on all cards | ![Floating](../assets/screenshots/floating.jpg) |
| **Floating Center Reflection** | Blurred background with date/time, reflection only on center card | ![Floating Center](../assets/screenshots/floating-center-relfection.jpg) |
| **Floating Clean** | Blurred background with date/time, no reflections | ![Floating Clean](../assets/screenshots/floating-clean.jpg) |

#### Floating Clear (without blur, with widgets)
Replaces the heavily blurred background with the original high-resolution wallpaper in crisp detail, keeping the sleek Date & Time overlay on top.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Floating Clear** | High-res wallpaper with date/time, reflections on all cards | ![Floating Clear](../assets/screenshots/floating-clear.jpg) |
| **Floating Clear Clean** | High-res wallpaper with date/time, no reflections | ![Floating Clear Clean](../assets/screenshots/floating-clear-clean.jpg) |

#### Floating Minimal (without blur, no widgets)
Offers a completely unobstructed view of your high-resolution wallpaper by removing the Date & Time overlay entirely, keeping focus purely on the 3D card deck.

| Layout | Description | Screenshot |
|--------|-------------|------------|
| **Floating Minimal** | High-res wallpaper, no date/time, reflections on all cards | ![Floating Minimal](../assets/screenshots/floating-minimal.jpg) |
| **Floating Minimal Clean** | High-res wallpaper, no date/time, no reflections | ![Floating Minimal Clean](../assets/screenshots/floating-minimal-clean.jpg) |

---

### Hexacomb
A honeycomb grid of hexagonal tiles, navigable in both directions (columns and rows) instead of a single strip. Idea for this layout taken from [Horizon0427/Arch-Config](https://github.com/Horizon0427/Arch-Config) — the hex-grid wallpaper picker there was the inspiration, rebuilt here from scratch for Quickshell/QML.

![Hexacomb](../assets/screenshots/hexcomb.jpg)

---
### Grid View
A two-pane grid browser — thumbnails on the left, a live "Currently Active" vs "New Selection" comparison on the right so you can preview before committing. Focused thumbnail gets an accent-color outline; filename and `ENTER`/`ESC` hints shown below the preview.

![Grid View](../assets/screenshots/grid-view.jpg)

---

> Screenshots referenced above go under `assets/screenshots/` in this repo
