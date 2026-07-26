# Walkthrough - Bria 2.0 API Name Fix

This update specifically addresses the **Server Error (500)** by providing the mandatory `api_name: "/png"` required by the newer Bria RMBG 2.0 AI spaces.

## Changes Made

### 1. Explicit API Targeting
Modified [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart) to include `"api_name": "/png"` in the first attempt. This tells the Gradio server exactly which function to run (direct PNG background removal).

### 2. Multi-Payload Fallback
The service now attempts three different data formats:
1. **Modern with API Name** (Bria 2.0)
2. **Standard FileData** (Bria 1.4 / Gradio 4)
3. **Legacy Base64 String** (Gradio 3)

### 3. Dynamic File Path Resolution
Improved how the app finds the result file. It now checks for both `/file=` and `/gradio_api/file=` paths dynamically.

## Next Steps

1.  **I-run ang `sync_frontend.bat`** sa iyong computer.
2.  **I-push sa GitHub**:
    ```bash
    git add .
    git commit -m "Fix: Add api_name /png for Bria 2.0 compatibility"
    git push origin master
    ```
3.  **Check Render**: After the "Live" status, try Magic Clean again.
