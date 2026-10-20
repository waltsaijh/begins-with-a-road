# scripts 結構整理與驗證（2026-10-20）

搬移 24 支腳本及其 `.gd.uid`，按照資料、階段協調、出生、介面和渲染的責任分類。遊戲、測試及工具的 252 個腳本／場景／Resource／專案設定，在將新路徑還原為舊路徑後與 `a8397f7` 完全一致；本次沒有修改遊戲演算法或數值。

## 目錄調整

| 範圍 | 整理後位置 |
| --- | --- |
| 建造卡、地塊配置與候選 Resource | `scripts/cards/definitions/` |
| 關卡、ACT、波次及出生群組 Resource | `scripts/levels/definitions/` |
| ACT 入口擴張與候選搜尋 | `scripts/levels/expansion/` |
| 關卡 HUD、時間線與起點對話框 | `scripts/levels/presentation/` |
| 敵群與出生排程／快照 | `scripts/enemies/spawning/` |
| 敵人頭頂狀態與獨立開波按鈕 | `scripts/enemies/presentation/` |
| 地形端點、貼齊與配置驗證 | `scripts/map/terrain/` |
| 地塊資料集合與成本快取 | `scripts/map/tile/` |
| 候選行程與配額機率 | `scripts/navigation/routes/` |
| 攻擊傷害快照 | `scripts/combat/attacks/` |

同步更新場景、資源、preload、測試與詳細系統文件。架構文件新增完整目錄樹、子模組責任及建造／開波／每幀資料流，仍以模組層級導覽為主。歷史測試報告保留當時路徑；本輪回歸產生的圖片與舊報告已還原，新的驗證結果另存本報告。

## 靜態與載入檢查

- 24 組搬移保留原 UID，74 個 script UID 均唯一。
- 189 處明確 script 引用可解析，現行程式與文件無舊 script 路徑殘留。
- Godot 4.7.2 編輯器匯入通過；216 個腳本、場景與資料資源均可載入。
- 專案主場景與 Web 匯出排除設定已還原；匯出用臨時測試分派器已移除。

## 執行回歸

Windows 共 14 項檢查通過：資源載入、關卡流程、地形端點、出生群組、選路配額、兵種資源、塔障礙、戰鬥、地塊配置、卡牌命名、敵人狀態、ACT 擴張、暫停／鏡頭，以及實際波次編輯器的編輯、Undo／Redo、儲存重載。

另有三個既有 UI 測試失敗；已用 `a8397f7` 的獨立快照、相同 Godot 與 DLL 對照，失敗計數及結果 JSON 完全相同：

| 測試 | 目前／提交前失敗數 | 範圍 |
| --- | ---: | --- |
| card_shop，headless | 11／11 | 合成滑鼠 hover、提起及重疊命中；隱藏渲染視窗的完整商店合成點擊流程亦曾超時，未列為通過 |
| debug_overlay | 4／4 | 固定 23 段橋路及共用線段頂點數斷言 |
| ui_scene_templates | 2／2 | 時間線圓點填色像素斷言 |

Web 使用單執行緒 release 匯出及 Edge 155。關卡流程、出生群組、戰鬥與敵人狀態四項斷言通過。以下限制分別記錄，未以「全部通過」概括：

- card_names 發生 `RuntimeError: null function`，在相同測試分派器匯出的提交前快照也重現；尚未修復。
- terrain_endpoints 的 `res://.godot/` 存檔往返、ACT 擴張的 `res://reports/levels/` 截圖寫入，在此 Web 測試匯出缺少對應目錄而失敗。相關功能以 Windows 回歸為準，這兩項 Web 測試未列為通過。
- 關卡測試在成功輸出結果並呼叫退出後，出現引擎 PagedAllocator 清理訊息；另有快速場景變更時的 WebGL buffer 警告。與測試斷言分開保存，未判為無 console 訊息。

完整斷言輸出及 Web 清理訊息見 [驗證資料](scripts_structure_2026-10-20.json)。未重跑耗時效能壓測；本次僅驗證腳本搬移後的載入與功能。

目前架構見 [architectures.md](../../docs/architectures.md)。
