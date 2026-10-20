# 專案結構整理（2026-10-20）

測試、工具與歷史報告依功能分類，共搬移 267 個檔案（含腳本 UID）。遊戲內容仍以 `assets/data/` 為設定來源；共用場景仍放在各分類的 `components/`。

- `tests/`：cards、combat、enemies、levels、maps、navigation、editor、fixtures、native。
- `tools/`：build、assets（含 Blender 原型工具）、web、benchmarks。
- `reports/`：對應功能報告、模型預覽與 project 整理紀錄。
- 首頁改為常用編輯入口與目錄導覽，系統細節保存在 `docs/systems.md`；維護原則見 `docs/architecture.md`。
- 同步更新 Godot 引用、外掛測試入口、工具根目錄推導、C++ include、動態報告路徑及 Web 匯出排除條件。
- 移除四個空白的根目錄範本資料夾。

整理時也固定了獨立測試場景的地形原點；兵種資源測試改驗證目前 Heavy 血量／護盾／速度的儲存往返，避免把舊平衡值當成資料格式要求。

驗證範圍：214 個 Godot 腳本／場景／資料資源均可載入；實際波次編輯器、關卡流程、地形端點、出生群組、ACT 擴張、商店、爆散特效、兵種資源、選路配額、地塊浮起與 UI 範本檢查均通過。另已檢查 Python／PowerShell／JavaScript 語法、C++ include 路徑與文件連結，未發現搬移前路徑殘留。

本次整理前的檔案備份及搬移清單留在本機 `.godot/project_structure_backup.zip` 與 `.godot/project_structure_migration.json`，不作為遊戲依賴。
