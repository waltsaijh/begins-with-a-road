# Blocky Grunt

以專案既有 grunt 為參考，透過 Blender MCP 製作的圓角方塊步兵。保留紅衣、深灰頭盔、紅冠、木盾與長矛，改成較厚實的方形輪廓；邊緣使用三段小倒角，平面保持平整。

- `blocky_grunt.glb`：遊戲用模型，5 個網格、1 個材質、6,398 個三角形。64×64 調色盤貼圖已內嵌，無外部貼圖依賴。
- `palette.png`：可編輯的調色盤備份。
- `source/blocky_grunt.blend`：Blender 原檔，保留各部件、肢體動畫、燈光與預覽相機。`Blocky Grunt Studio` 用於編輯；`Blocky Grunt - Game Export` 為合併後的遊戲版本。
- `reports/assets/blocky_grunt.png`（專案根目錄）：正交相機預覽。

在 `assets/data/troops/*.tres` 的 **Model** 欄位指定 `blocky_grunt.glb` 即可使用。自動辨識走路動畫，也可明確填入 `Walk-loop`；它是 1 秒的循環，包含雙腿、雙臂及身體起伏。原點在雙腳底部，面向 Godot -Z，旋轉可保持 `(0, 0, 0)`。含長矛總高約 0.678、冠頂約 0.644 世界單位；若希望接近原 grunt 的高度，可將 Model Scale 設為 `(0.9, 0.9, 0.9)`。

角色已作為獨立素材保存，尚未指派給既有兵種。

重建工具依序為 `tools/assets/blender/build_blocky_grunt.py`、`tools/assets/blender/export_blocky_grunt.py`、`tools/assets/blender/preview_blocky_grunt.py`，在 Blender 的 Python 環境或透過 MCP 執行。首次建立時從乾淨的新場景執行；工具會建立新場景，不會清空既有場景。匯出階段把同一肢體的零件合併成網格，並將配色寫入調色盤 UV；原始部件仍保留於 Studio 場景。
