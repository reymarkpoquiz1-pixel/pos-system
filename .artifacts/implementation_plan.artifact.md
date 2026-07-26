# Implementation Plan - Magic Clean "Super Stable" Fix

This plan implements a highly resilient background removal service designed to handle various AI server constraints (file size, payload format, and endpoint naming) to resolve the recurring 500/404 errors.

## Proposed Changes

### Frontend Service

#### [MODIFY] [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart)
- **Lower Size Limit**: Set a stricter limit of 3MB to prevent server-side memory crashes on free AI spaces.
- **Payload Polymorphism**: For each endpoint, the service will now try:
    1. Modern Gradio `FileData` object.
    2. Explicit `api_name: "/predict"`.
    3. Raw Base64 string (without the `data:` prefix) as some older spaces expect this.
- **Increased Space Variety**: Add a third backup space URL.
- **Response Validation**: Better handling of the returned data to ensure it's a valid image path before attempting download.

## Verification Plan

### Manual Verification
1. Run `sync_frontend.bat` to build the updated logic into the web app.
2. Push to GitHub and wait for Render deployment.
3. **Test Case**: Upload a small image (~500KB) and click Magic Clean.
4. **Retry Logic**: If a "Server Error" message appears with a Retry button, wait 5 seconds and click Retry to ensure the space is "awake."
