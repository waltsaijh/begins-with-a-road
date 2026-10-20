# 專案清理與選路模式（2026-10-19）

保留全部塔圖示、三張遊戲地圖、模型來源、資產重建工具與原生 SDK。

移除 104 個已退役 ST／Yen／detour 相關核心、失效測試／探查場景、舊分析工具與歷史輸出。原始檔案備份於 `.godot/cleanup_removed.zip`；完整移除清單見 `.godot/cleanup_manifest.json`。

刪除未使用的 ShopConstants.ACCENT 與純 GDScript 專案殘留的 .NET assembly 設定。reports/.gdignore 避免將驗證截圖及分析檔匯入成遊戲資源。地塊成本 C++ 測試改用目前的 diverse_routes_core.hpp；navigation_optimization.gd 改驗證現行路線池摘要與快取副本。

右下角可在波次之間切換目前兵種的 Uniform／Softmax（soldier 預設 Uniform，其餘預設 Softmax），也可使用 Troop.route_selection。兩種模式先按 score - min_score < score_threshold 篩選；Uniform 等機率，Softmax 使用 route_temperature 加權。模式切換會失效所有起點計畫，但已準備的波次行程不改變。Uniform 僅對有限候選池等機率。現版每波按局部序號／總數分配路線配額後打亂出發順序，詳見 route_distribution.md。

驗證：19 項 Godot headless 功能測試、實際畫面的 card_shop 測試、route_distribution 模式／門檻／快取／固定波次測試，以及 C++ tile_costs 的 512 張地圖窮舉對照均通過。商店 hover 依賴實際滑鼠畫面，headless 測試會回報 hover 失敗；實際 OpenGL 畫面驗證為零失敗。另已檢查新選單截圖及所有 literal res:// 資源引用。
