# 介面字型

只保留兩個 Noto Sans TC 字型檔，兩者都包含繁體中文、英文、數字與常用符號：

- `NotoSansTC-Light.ttf`：weight 300，專案預設介面、卡牌塔名、價格與非當前 ACT。
- `NotoSansTC-Medium.ttf`：weight 500，卡牌地塊前綴與時間線目前 ACT 的強調文字。

兩個檔案由 Noto Sans TC 可變字型固定字重產生，保留原有字元涵蓋範圍。中英文直接使用同一個字型，不需要另外的英文來源或 FontVariation 備援資源。

Light 的匯入 oversampling 維持 0.0，依 viewport 自動取樣，保留原本灰階抗鋸齒與 hinting。固定提高到 4.0 的作法已撤回，因實際畫面的一般文字出現過細與破碎邊緣。主選單／設定與暫停按鈕的 hover 僅變黑，不縮放文字，不以全域字型匯入倍率處理 hover。原字級、字重與命中布局不變；Medium 沿用原匯入設定。

專案預設設定於 Project Settings → GUI → Theme → Custom Font。卡面及商店的明確字型引用在各自場景；時間線的 Current Act Font 使用 Medium。

授權見 `OFL.txt`，為 SIL Open Font License 1.1。
