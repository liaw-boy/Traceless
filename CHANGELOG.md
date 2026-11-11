# Changelog

## 1.1.0

改名為 **Traceless（無痕）**，並全面檢修。

### 安全
- 修正管理者權限備援的指令注入：含 `$(...)`、反引號等字元的檔名過去會以 root 身分被 shell 執行。
- 管理者權限改為整批只問一次，不再逐項詢問；不會覆蓋垃圾桶中同名項目；家目錄內的檔案不再要求密碼（root 也無法繞過 TCC）。
- 刪除前檢查加入 `..`、控制字元、大小寫別名、symlink 上層的防護；不再允許刪除殘留根目錄本身與 `~/.Trash`。
- Info.plist 中的名稱經過驗證才用於組合路徑。
- 系統與 Apple App 的資料不再預先勾選；憑證相關資料夾不會被列為殘留。
- 過短或可疑的 bundle ID（例如只有 `com`）不再用於前綴比對，避免誤中其他廠商的背景服務。
- `/Library` 系統層項目一律不預先勾選；「重置」只清除家目錄內的資料。
- 只有 root 擁有的 launchd 設定檔才能指向 PrivilegedHelperTools 內的 helper。
- 管理者權限搬移改用 `mv -h`，並確認垃圾桶是真實目錄、來源的每一層上層目錄都由 root 擁有，防止 symlink 競態。
- 只允許刪除 Applications 第一或第二層的 `.app`，不允許 App 內嵌的子 App。

### 修正
- 應用程式列表不再出現系統內部元件、App 內嵌的輔助程式、開發建置產物與 DMG 中的 App。
- LaunchAgent、崩潰報告、Group Container 比對改用邊界比對，避免「Go」誤中 Google 項目等誤判。
- 只刪除部分檔案時，App 不會再從列表消失。
- 快速切換 App 時，不會顯示上一個 App 的掃描結果。
- 「清理選取」只作用於畫面上可見的項目，並先確認。
- 殘留掃描會等已安裝清單載入完成，避免剛開啟時誤判一大批殘留。
- 從未開啟過的新 App 不再被歸為「長期未開」。
- App 大小包含內嵌的套件，列表與明細數字一致。

### 新增
- 掃描 Application Scripts、Cookies、`/Library` 下的 Application Support／Caches／Logs、LaunchAgents／LaunchDaemons、PrivilegedHelperTools。
- 側邊欄顯示版本號；⌘1～⌘3 切換頁面；⌘⌫ 移至垃圾桶。

### 介面
- 改用原生 macOS 元件，跟隨系統淺色／深色與強調色，移除漸層與發光效果。
- 新圖示：從凹槽中被取出的 App，深色與著色圖示模式下同樣清楚。

## 1.0.0
- 初版。
