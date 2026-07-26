# Implementation Plan - Magic Clean Stability & Recovery Fix

This plan aims to restore the Magic Clean (Background Removal) feature by reverting to the more stable Bria RMBG 1.4 model and implementing a robust "Server Wake-up" and error reporting system.

## User Review Required

> [!IMPORTANT]
> The AI servers at Hugging Face sometimes "sleep" to save power. If the first attempt at Magic Clean fails, wait 10 seconds and try again—this "wakes up" the server.

## Proposed Changes

### Frontend Service

#### [MODIFY] [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart)
- **Revert to RMBG 1.4**: Make `briaai/BRIA-RMBG-1.4` the primary endpoint.
- **Smart Payload Fallback**: Implement three levels of fallback:
    1. Gradio 4 `FileData` format.
    2. Gradio 3 `Simple Array` format.
    3. Direct Base64 string format.
- **Detailed Error Catching**: Catch specific HTTP status codes and provide actionable feedback (e.g., "Server Busy" for 503, "File Too Large" for 413).

### Inventory UI

#### [MODIFY] [products_view.dart](file:///C:/pos-all-in-one/frontend/lib/features/inventory/views/products_view.dart)
- **Enhanced SnackBar**: Update the error display to include the specific reason for failure, helping the user understand if they need to resize their image or wait for the server.

## Verification Plan

### Manual Verification
1. Run `sync_frontend.bat` to build the new JS.
2. Push to GitHub and wait for Render.
3. **Test Case 1**: Use a small image (< 1MB).
4. **Test Case 2**: If failure occurs, retry once after 10 seconds to verify "wake-up" logic.
