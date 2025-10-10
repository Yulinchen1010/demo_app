# 疲勞預測雲端服務指引

本專案提供一個 FastAPI 雲端服務，負責接收 APP 上傳的肌肉 MVC 感測資料、進行預測並提供結果查詢。以下說明如何啟動服務、檢視預測以及確認 APP 與雲端的連線狀態。

## 1. 啟動服務

```bash
uvicorn ai_predictor.fastapi_fatigue_service:app --reload --host 0.0.0.0 --port 8000
```

啟動後可透過 `http://localhost:8000/docs` 進入自動產生的 Swagger UI 操作或測試 API。

## 2. 檢視預測結果

1. **即時狀態**：
   - 端點：`GET /status/{worker_id}`
   - 內容：顯示最新 MVC 值、與初始值的差異、建議措施，以及「prediction_preview」欄位提供未來 30 分鐘 (每 10 分鐘一次) 的預測摘要。

2. **完整預測曲線 (JSON)**：
   - 端點：`GET /predict/{worker_id}?horizon=120`
   - 內容：每 10 分鐘一筆的預測資料，可自由調整 `horizon` (分鐘數，預設 120)。

3. **圖表視覺化**：
   - 端點：`GET /chart/{worker_id}?horizon=120`
   - 內容：回傳 PNG 圖檔，包含預測的 MVC 百分比趨勢與風險區域，可直接於瀏覽器中預覽。

## 3. 確認 APP 是否成功連線雲端

使用新的監測端點即可確認 APP 是否持續上傳資料：

- 端點：`GET /connection/{worker_id}?freshness_minutes=5`
- 回傳欄位說明：
  - `connected`：布林值，表示最近 `freshness_minutes` 分鐘內是否收到資料。
  - `minutes_since_last_upload`：距離最近一筆上傳已過多久。
  - `samples_preview`：最新 5 筆上傳資料，方便比對數據內容。
  - 其他欄位如 `latest_mvc`、`total_records` 亦可協助了解資料量與內容。

> 若需要確認整體系統狀態，也可呼叫 `GET /health` 取得資料總量與模型載入狀態。

## 4. 產生或清理測試資料

- 產生測試資料：`POST /test/generate/{worker_id}?count=20`
- 清空特定工作者資料：`DELETE /clear/{worker_id}`
- 全部清空：`DELETE /clear_all`

## 5. 常見問題

- **看不到預測資料？**
  - 請先確認對應 `worker_id` 已有歷史紀錄，可用 `GET /status/{worker_id}` 或 `GET /connection/{worker_id}` 檢查。
- **APP 顯示連線異常？**
  - 檢查 `connection` 端點回傳的 `minutes_since_last_upload` 是否超過門檻；必要時透過 `samples_preview` 對照 APP 送出的資料內容。

如需進一步整合或除錯，建議透過 Swagger UI 或任何 HTTP 客戶端 (例如 Postman) 搭配上述端點操作。
