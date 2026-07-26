# Implementation Plan - Precision Magic Clean Fix (Bria 2.0 Compatibility)

This plan fine-tunes the Magic Clean service to match the specific requirements of the Bria RMBG 2.0 AI space, which uses specialized endpoints and is stricter with payload formats.

## Proposed Changes

### Frontend Service

#### [MODIFY] [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart)
- **Targeted Endpoints**: Add `/api/png`, `/gradio_api/api/png`, and `/gradio_api/call/png` to the discovery list.
- **Payload Refinement**:
    - Ensure the Base64 data includes the proper MIME type.
    - Implement a specific "fn_index" or "api_name" if needed based on common Gradio 4 patterns.
- **Improved Error Catching**: Capture and display the server's specific error message if it's not a 200/404 (to help diagnose if it's a "File Too Large" issue).

## Verification Plan

### Manual Verification
1. Run `sync_frontend.bat` locally.
2. Push to GitHub.
3. Test Magic Clean with a standard product image.
