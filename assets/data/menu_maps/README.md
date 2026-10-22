# 選圖資料

`frontier.tres` 保存選圖頁的翻譯 key、正式 Level Resource 與可執行場景路徑。現在只有邊境前哨，切換箭頭停用；`9x9`／`11x11big` 等獨立試驗場景不是正式關卡選項。

預覽使用 `scenes/menus/components/frontier_preview.tscn`，直接實例化正式關卡引用的地形場景，以唯讀 GridMap 顯示道路與端點；固定裝飾石柱、相機皆保存在場景。Inspector 的 Top Clearance／Bottom Clearance／Horizontal Fraction 決定為標題與底部操作保留的取景空間；Zoom 控制自動取景後的視覺倍率，目前為 1.0（相較前版縮小 20%），Bottom Clearance 為 280px，相機水平旋轉為 0°，讓地圖長軸水平呈現。沒有載入 LevelSession、波次、商店或導航。

新增可玩地圖時：

1. 先建立正式 Level `.tres` 與引用它的可執行關卡場景，再建立 MenuMapDefinition `.tres`。兩個 Level 引用必須一致。
2. 建立明確保存的預覽場景，Terrain 直接引用該 Level 的地形；根節點使用 `map_preview.gd` 並指定對應選圖 Resource。
3. 將預覽實例放進 `scenes/menus/main_menu.tscn` 的 MapPreviews。子節點順序就是選圖順序；有多張時會啟用前後切換，不在執行時生成 UI 或地形。

地圖名稱與描述使用 `assets/translations/card_names.csv` 的雙語 key；ACT／波次數直接讀取 Level，不另存可能過期的數字。選圖介面位於 `scenes/menus/map_selection.tscn`，可直接調整字級、留白、按鈕及淡入動畫。

選圖後按下一步，只把同一場景內 Details 的描述區換成兩欄、兩排的本局設定區（右下為暫定提示），再按開始作戰；地圖、相機、標題、地圖名稱與底部操作位置不變。RunOptions 中的難度、起始手牌與額外事件均為固定可編輯節點，目前僅供流程預覽，不套用到關卡資料或實際戰局。返回／Esc 先回選圖並保留值，再次返回才回主畫面；get_run_options() 與 launch_requested 的字典提供未來規則介接入口。
