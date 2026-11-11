# AppSweep 🧹 (macOS 應用程式深度清理與移除工具)

一個專為 macOS 打造、深度借鑑業界頂級工具（**CleanMyMac** 與開源標竿 **Pearcleaner**）的專業級、原生、自訂設計系統應用程式移除軟體。

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Custom Design System](https://img.shields.io/badge/UI-Custom%20Pro%20Studio-purple.svg)

---

## 🎨 全新自訂設計系統 (Bespoke Pro Studio UI)

告別 macOS 預設的灰色原生元件，AppSweep 全面採用客製化的 **Studio Pro Dark** 視覺體系：
- 🎯 **統一官方應用圖示 (Dock & In-App)**：Dock 圖示與軟體內頂部品牌圖示 100% 統一，採用深色鈦金屬回收艙與霓虹渦流清理立方體設計，象徵極致乾淨移除。
- 💊 **自訂滑動膠囊過濾器 (Sliding Capsule Filter)**：提供 `全部`、`第三方`、`長期未開`、`系統` 四種維度切換，點選具備流體幾何動畫與發光背景。
- 🔀 **多維度即時排序器 (Multi-Dimension Sorter)**：
  - 📦 **容量大小**（由大到小 / 由小到大）
  - 🕒 **上次開啟時間**（即時掌握閒置未使用的 App）
  - 📅 **安裝與修改時間**（由新到舊 / 由舊到新）
  - 🔤 **名稱**（A → Z）
- 📊 **視覺化儲存佔用色條 (Storage Breakdown Visualizer)**：
  - 如同 CleanMyMac 與 DaisyDisk，以彩色分段色條即時呈現主程式（藍）、快取（青）、支援資料（紫）、沙盒容器（靛）、偏好設定（橘）等佔用比例。
- ☑️ **自訂發光勾選方塊 (Custom Checkbox System)**：
  - 微光圓角勾選框，支援單檔點選、整列卡片點擊切換、以及分類標題一鍵全選 / 取消。
- 🎴 **發光焦點卡片 (Interactive App Cards)**：
  - 醒目的左側電光藍發光邊條，搭配晶透 Retina 高解析圖示與陰影。
  - 標示處理器架構標籤（`Apple Silicon` / `Intel` / `Universal`）與相對使用時間（例如 `2 天前開啟`、`超過 3 個月未使用`、`從未開啟`）。

---

## 🚀 獨家高階功能（借鑑 Pearcleaner & CleanMyMac）

1. **🔄 應用程式重置 (Reset Application)**：
   - 當軟體出現異常或佔用龐大快取時，無須刪除 App 本體，可透過「重置此應用」一鍵清除其偏好設定、暫存與沙盒資料，回歸出廠狀態。
2. **💤 長期未使用過濾 (Unused Apps > 3 個月)**：
   - 透過 macOS 系統底層中繼資料精確偵測最後啟動時間，一鍵找出被遺忘在角落但佔據數十 GB 的肥大應用程式。
3. **⚙️ CPU 架構識別 (Architecture Detection)**：
   - 高速解析 Mach-O 執行檔標頭，即時辨識為原生 `Apple Silicon (arm64)`、Rosetta 轉譯的 `Intel (x86_64)` 或 `Universal (通用架構)`。
4. **⚡️ Spotlight 毫秒級極速中繼提取**：
   - 擺脫傳統遍歷成千上萬檔案的轉圈延遲，百款應用程式容量與狀態於 0.18 秒內全數載入完畢。
5. **🧹 孤立殘留檔案清理 (Leftover Scanner)**：
   - 掃描過去已直接被丟入垃圾桶、但在 `~/Library` 中遺留數 GB 的舊資料，支援一鍵批次全清除。
6. **🛡️ 系統垃圾桶安全機制 (Safe Trash Routing)**：
   - 所有刪除皆調用 macOS 官方 `trashItem` API，非永久破壞性抹除，隨時可在 Finder 垃圾桶還原。

---

## 📦 安裝與執行

### 直接開啟使用
Release 版本已完成 Ad-hoc 簽名與 DMG 映像檔封裝：
```bash
# 直接啟動
open ./AppSweep.app

# 或開啟安裝映像檔安裝至 /Applications
open ./AppSweep.dmg
```

### 原始碼構建
```bash
cd <專案資料夾>

# 執行 6 項核心單元測試
swift test

# 重新構建 Release 版 .app 與 .dmg
./bundle.sh
```
