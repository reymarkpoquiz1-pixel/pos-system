# Implementation Plan - Bria 2.0 API Name Fix

This plan fine-tunes the Magic Clean service to match the specific requirements of the Bria RMBG 2.0 AI space by using explicit API names and optimized payload structures to resolve the 500 Internal Server Error.

## Proposed Changes

### Frontend Service

#### [MODIFY] [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart)
- **Explicit API Name**: Include `"api_name": "/png"` in the JSON payload. This is required by the Bria 2.0 space to distinguish between image comparison and direct PNG generation.
- **Priority Endpoints**: Prioritize `/gradio_api/api/predict` and `/api/predict` which are the most reliable synchronous endpoints for Gradio 4.
- **Enhanced Data Handling**: Ensure the `session_hash` is unique and the `fn_index` is provided if needed.

## Verification Plan

### Manual Verification
1. Run `sync_frontend.bat` locally.
2. Push changes to GitHub.
3. Test Magic Clean with a standard product image.
