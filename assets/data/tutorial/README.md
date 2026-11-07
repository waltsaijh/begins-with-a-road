# 教學初始手牌設定

在 Godot 開啟 `intro.tres`，Inspector 的 **Starting Cards** 即為初始三張手牌，依陣列順序執行：第一張指定位置原向放置、第二張依 Guided Turns 轉到 hologram 方向放置（目前 180°）、第三張自由合法放置。

目前三張為獨立 BuildCard，方便直接編輯：

| 檔案 | 預設塔種 |
| --- | --- |
| `starting_01.tres` | 哨塔 |
| `starting_02.tres` | 迫擊砲 |
| `starting_03.tres` | 弩砲 |

打開單張卡的 Inspector，以 **Tower** 引用更換塔種、**Tile Preset** 引用更換道路組合；也可以直接在 Starting Cards 陣列更換整張卡或重排。修改後重新開始關卡即可套用，提示中的塔名及 hologram 會讀取新資料，不需要改腳本。

- **Guided Cells／Guided Turns**：對應前兩張的目標格與方向；改道路組合或塔占格後，請一併確保這兩次放置仍合法且入口到終點連通。
- **Upgrade Card**：商店教學要求購買的升級牌，預設哨塔。其塔種必須出現在初始手牌任一位置，升級 hologram 會尋找實際建好的同種塔。
- **New Card**：刷新後必出的新牌，預設交叉火力；其塔種必須不在初始三張中。若將交叉火力改入初始牌，請將此欄改成另一個塔種。

教學波次另由 `assets/data/levels/tutorial.tres` 的 Acts → Waves 編輯，目前 1 ACT、3 波。首波後進入商店教學，買到新牌後恢復一般建造／交易及剩餘波次；第三波與最後 ACT 獎勵結束才通關。
