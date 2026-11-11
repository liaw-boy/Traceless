# Traceless（無痕）

移除 macOS 應用程式不留痕跡：除了 `.app` 本體，也一併找出它留在系統裡的偏好設定、快取、容器、背景項目等檔案。所有東西都移到垃圾桶，清空前都能從 Finder 還原。

需求：macOS 14 以上。

## 功能

- **應用程式**：列出 `/Applications`、`~/Applications` 與系統 App，可依「第三方／長期未開／系統」篩選，依大小、上次開啟、安裝時間、名稱排序。
- **相關檔案**：依 bundle ID 與名稱比對 `~/Library` 與 `/Library` 下的偏好設定、Application Support、Caches、Containers、Group Containers、Application Scripts、Saved State、WebKit / Cookies、Logs、LaunchAgents / LaunchDaemons、PrivilegedHelperTools、虛擬音訊裝置驅動（HAL）。launchd 項目依擁有權判定（Label、AssociatedBundleIdentifiers、Program 路徑）。
- **重置**：保留 App 本體，只清除它的資料，讓它回到剛安裝的狀態。
- **殘留檔案**：找出已刪除 App 留下的資料夾。預設全部不勾選，需自行確認。
- **驅動與背景**：列出所有第三方驅動、虛擬音訊／鏡頭、網路延伸、開機背景服務與輔助程式，用白話說明用途，標出哪些屬於已移除的 App（以程式碼簽章 Team ID 判斷）。能刪的移到垃圾桶，macOS 只允許在系統設定關閉的則寫明位置並提供直達按鈕。
- **外觀**：跟隨系統、淺色或深色（設定 ⌘,）。
- **拖曳移除**：把任何 `.app` 拖進視窗即可分析。

## 安全設計

- 每個刪除路徑都要先通過 `PathUtils.isSafeToDelete`：拒絕 `..`、控制字元、大小寫別名與指向受保護位置的 symlink 上層；個人資料夾、憑證、Apple 資料庫一律不碰；只允許已知的殘留位置與 Applications 資料夾內的 `.app`。
- 系統 App 不能移除；Apple App 的資料（如備忘錄、郵件）不會預先勾選。
- 系統資料夾內的檔案需要管理者權限時，整批只詢問一次密碼，路徑以 AppleScript `quoted form of` 傳遞，不會被 shell 解譯。
- 沙盒容器需要「完全取用磁碟」權限；App 會在需要時引導開啟。

## 建置

```bash
swift build          # 開發版
swift run Traceless     # 直接執行
swift test           # 單元測試
./bundle.sh          # 產生 Traceless.app 與 Traceless.dmg（ad-hoc 簽章）
```

版本號在 `VERSION`，build 號取 git commit 數。變更記錄見 `CHANGELOG.md`。

## 安裝與授權

1. 打開 `Traceless.dmg`，把 Traceless 拖進「應用程式」。
2. 第一次開啟：這是 ad-hoc 簽章（沒有 Apple Developer ID），macOS 會擋下。到「系統設定 › 隱私權與安全性」最下方按「仍要打開」，或在 Finder 對 Traceless 按右鍵 › 打開。
3. 授權「完全取用磁碟」：「系統設定 › 隱私權與安全性 › 完全取用磁碟」按 + 加入 Traceless 並打開。沒有這個權限也能用，只是沙盒容器（`~/Library/Containers`）無法移除。

為什麼可以放心授權：
- 原始碼都在這個 repo，沒有任何網路功能。
- 只會「移到垃圾桶」，不會永久刪除；每一個路徑都先經過 `isSafeToDelete` 白名單檢查（見上方安全設計與 `Tests/`）。
- 管理者密碼只在要移動 `/Applications`、`/Library` 內 root 擁有的檔案時才會詢問，由 macOS 原生對話框處理，Traceless 拿不到密碼。

注意：ad-hoc 簽章每次重新建置都會改變，macOS 會把新版當成不同的 App，**重新建置後需要再授權一次**。若要避免，可用固定的簽章身分（Apple Developer ID，或鑰匙圈中自建的程式碼簽署憑證）執行 `SIGN_IDENTITY="憑證名稱" ./bundle.sh`。
