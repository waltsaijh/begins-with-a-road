# Blender MCP → GLB → Godot

此流程在後續使用者授權製作資產時執行。建立 Skill 本身不執行任何建模／匯出操作。

## 來源、命名與可重跑性

下列為本次新增的製作慣例；目前不建立空白資產或 placeholder。

| 內容 | 存放方式 |
| --- | --- |
| 原始檔、建模／匯出腳本、規格記錄 | `tools/assets/blender/<asset_id>/model.blend`、`build.py`、`model-spec.md`；腳本可含匯出，較複雜才拆 export.py |
| 交換模型 | `assets/models/<category>/<asset_id>.glb`，category 沿用 towers／traffic／endpoints 等分類 |
| Godot 外觀包裝 | 同分類 `<asset_id>.tscn`，只在任務包含接入時建立／調整；替換現有檔前核對引用與 UID |
| 臨時比較圖與檢查結果 | `.godot/test-results/modeling/<asset_id>/`，不把例行圖堆入 reports |

asset_id／檔名採小寫 snake_case；例 `mortar_v2`。模型根／功能節點採清楚 PascalCase（如 MortarModel、FixedBase、AimPivot、RecoilAssembly、Level2、Level3）；mesh 採 `<asset_id>_<part>_mesh`，材質採 `<asset_id>_main`／`_structure`／`_accent`。不能為統一名稱破壞現有 NodePath。

日後首次建立 `tools/assets/blender/` 時放 `.gdignore`，避免 Godot 掃描 `.blend` 並在匯入階段依賴 Blender 安裝。Web 既有匯出排除 tools；不把 `.blend` 放到 assets。提交來源、腳本、GLB、wrapper 與源側 `.import`（生成後），不提交 `.godot` 快取與 `.blend1` 備份；只有實際引入備份時才調整 ignore。

規格記錄至少含：來源／GLB／wrapper 路徑、目標塔與 preset ID、局部 footprint／錨點／正面、尺寸 AABB、pivots／markers／升級件清單、材質值、Blender／Godot／匯出器版本、執行方式／固定 seed、匯出選項、幾何統計，以及已驗證／未驗證項目。

## MCP 操作

1. 發現當次可用的 Blender MCP；先 `get_addon_status`、`get_scene_info`，必要時用只讀 Python 列出所有物件及 collection。連線失敗就回報工具、原始錯誤和失敗步驟，不自行改連線設定或改用未授權素材服務。
2. 不假定 live Blender 是空檔。將本資產放專屬 `BWAR_<asset_id>` collection，預覽相機／燈／參考格網放獨立 `BWAR_PREVIEW_<asset_id>`；重跑只重建腳本明確擁有的物件／mesh／material。不清空整個場景、不清 orphan、不刪無關 Cube／使用者資料。
3. 先將 Python 保存到來源路徑，再透過 `execute_blender_code` 分段執行。user_prompt 使用使用者本次目標原文。設定參數集中於腳本開頭，隨機才指定固定 seed；透過 bpy.data／bmesh 優先減少對 selection／active mode 的依賴。
4. 每階段 print 尺寸、物件數及檢查結果，並用 `look` 檢查實際畫面。工具、屬性或 enum 依目前 RNA 查詢；不存在時明確報錯，不靜默略過關鍵匯出設定。
5. 重跑兩次比較本資產的物件／材質數、AABB、三角形和節點路徑；不得有 `.001` 累積、變換漂移或 unrelated collection 變動。
6. 保存專用 `.blend` 時確認目標路徑與內容；不要把另一份 live 檔案的無關資料當成資產來源。需要隔離時用獨立 Blender scene／另開工作檔或資料區塊輸出，並保留使用者原工作檔；不得未經要求覆寫原檔。

## 單位、座標、原點

- Blender：Metric、Unit Scale=1，Z up，X 右，**+Y 為資產正前方**。標準 glTF Y-up 轉換後，Blender `(x,y,z)` 對應 Godot `(x,z,-y)`，因此 +Y 對應 Godot −Z，+X 仍為右舷。
- 只由 glTF 匯出器做一次軸轉換；不要再對整個模型手動旋轉 −90°，也不要因一般 glTF 資產正面慣例而翻轉本作武器方向。
- 根 Empty 位於錨點 `(0,0,0)`、rotation=0、scale=1；底面 Blender Z=0。多格例：Godot 局部格 `(0,+1)` 對應 Blender `(0,-1,0)`，保留錨點而非對整體置中。
- Apply mesh 的 scale／必要 rotation 後仍須保留零件世界位置及機械 pivot；不能把 AimPivot／RecoilAssembly／砲口位移一併清零。鏡像落實為正確幾何與法線，不留負縮放。
- 匯入後測量1格尺寸、+Y up及−Z射向，不能靠 Godot Root Scale 或轉整棟修補單位／軸錯誤。必要的 0.025 接地視覺差值見專案契約。

## 正交遊戲視角預覽

從 project-spec 的執行期公式建立相機，以整張示意格網的 focus 取景；只把目標塔框滿畫面的 angles 圖不足以驗收遠景。

- 將 Godot 相機位置／focus 用反轉換 `(gx,-gz,gy)` 放到 Blender，camera type=ORTHO，朝 focus，Blender 本地 −Z 為視線、+Y 為相機上方。保持45°俯角、30°初始方位；補查四方位與最遠縮放。
- 保持同一解析度與長寬比。不要直接假設 Blender ortho_scale 等於 Godot size：依實際 Godot.keep_aspect、viewport 比例及 Blender camera.data.view_frame(scene=...) 得到水平／垂直跨度，調整 ortho_scale 使兩者吻合。以1格參考物的投影像素驗證，記錄相機值。
- 預覽先用純灰看剪影，再套主色；與現有道路／鄰塔對照。使用現有光向與環境色作近似，不加入戲劇性輪廓光、景深或透視遮掩問題。
- 先在正式遠景檢查，再放大看幾何。近景看不出的細節可刪，但近景可見的機械接合必須說得通。

## GLB 匯出

讀取當前 `bpy.ops.export_scene.gltf.get_rna_type().properties` 確認可用的選項／enum，再保存實際使用值到 build.py／規格。使用 GLB、自含幾何與簡單PBR材質、標準 +Y up、僅目標資產的選取層級；不依賴 Draco／額外解壓外掛或下載服務。

- 包含 root、所有功能 Empty／pivot、目標 mesh 及交付的 Level2／Level3；不要因隱藏升級件而漏匯出。預覽相機／燈／格網／布林 cutter 不進 GLB。
- 匯出前在副本上落實需要的 bevel／boolean／triangulation，保留可編輯來源。檢查三角化後薄片、孔壁、法線、材質、退化面及重面。
- 靜態／剛體建築不帶無用骨架、動畫或 blend shape。需要遊戲控制的部件維持獨立節點，不把整個模型 join；合併同一靜態群組，避免每根小柱各一份mesh／材質。
- 匯出 normals；沒有 normal map 就不為它加入 tangents／UV 貼圖依賴。無貼圖不等於可以省略自訂 shader 所需通道。
- 保存來源後匯出，重新讀取 GLB 的節點、材質與 bounds；確認沒有外部圖片／buffer、額外 root 轉換或鏡像。

## Godot 匯入與材質

以 GLB 作交換來源，`.tscn` 作可重匯入的外觀包裝，遊戲腳本、Marker3D、metadata 和資源引用由 Godot 層持有；不編輯 `.godot/imported` 內容。外觀接入仍需檢查 TowerBodyVisual 分支，不能宣稱單改 model 就完成。

1. 先用原始簡單 PBR 匯入作尺度／軸向／節點檢查，Godot root scale=1；透過 wrapper 或 Import 的外部材質引用保留重匯入設定。Blender Empty 僅作位置參考，需要 Marker3D 的路徑在 wrapper 明確建立。
2. 關閉非必要動畫、碰撞與 NavMesh 生成；不使用 `-col` 等自動碰撞命名暗示。遊戲占格／連通性由既有資料系統決定，不由 mesh 體積決定。
3. `solid_color` 需要 COLOR、UV／UV2、CUSTOM0=RGBA float（靜態w=0）、CUSTOM1=RG float（roughness／specular）。普通 GLB 不提供此專案自訂語意。直接指定 solid_color.tres 會有通道缺失風險。
4. 任務包含正式純色接入時，先用 `tools/assets/solid_mesh_baker.gd` 的 supports／mesh 對**該資產的靜態網格**離線處理，保存專用 `.res` 並在 wrapper 引用；保留樹／變換／砲口。此類 `.res` 為 GLB 衍生物，GLB 仍是交換來源。先檢查 StandardMaterial3D 的設定是否受支援，不靜默改材質來通過。
5. 不直接執行全專案 `bake_solid_models.gd` 當新GLB匯入器：它目前列舉 Sentry及特定既有資料夾，不包含一般新塔GLB；執行會重寫其他資產。共用baker拒絕 skinning／blend shapes／authored LODs，使用前核對匯入 LOD 設定；有這些資料就保留來源並回報限制。
6. 任意外部模型原材質有既有保留例外，但本作自製不透明建築以可沿用共用純色管線為目標。尚未轉換的PBR檢查品標為未完成正式材質接入，不能用新增每塔shader規避。
7. 本次範圍含接入才驗證正式外觀與 hologram、90°四向、接地、瞄準／砲口／後座、升級與空艇巡航。於獨立測試場景檢查；不為美術測試修改正式波次、卡牌池、道路、價格或戰鬥。
8. 再匯出／重匯入一次確認 wrapper 的引用、路徑與材質仍存在。Godot 真實渲染通過才寫成已接入；headless 匯入成功不能證明視覺品質或 Web 效能。

Godot 的匯入／外部材質行為依據：[Import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)、[Advanced Import Settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html)。API選項仍以安裝版本為準。
