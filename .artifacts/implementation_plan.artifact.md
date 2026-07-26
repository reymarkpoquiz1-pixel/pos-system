# Implementation Plan - Advanced Magic Clean Fix (Gradio 4 Compatibility)

This plan upgrades the Magic Clean service to handle the more complex API requirements of Gradio 4 on Hugging Face, specifically targeting the "404 Not Found" and "Payload mismatch" issues.

## Proposed Changes

### Frontend Service

#### [MODIFY] [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart)
- **Endpoint Expansion**: Add `/api/predict` (no prefix) and `/gradio_api/api/predict` to the search list.
- **Dual Payload Strategy**:
    - Attempt 1: Modern Gradio `FileData` object format.
    - Attempt 2: Simplified array format used by some specific space deployments.
- **Extended Timeouts**: Increase timeout to 60 seconds to allow cold-start spaces to respond.
- **Enhanced Debugging**: Log the specific URL and response body for every failed attempt to pinpoint the exact failure point.

## Verification Plan

### Manual Verification
1. Run `sync_frontend.bat` locally to generate the new JS build.
2. Push to GitHub.
3. Observe browser console logs or screen errors. If it still fails, the error message will now include the specific URL that failed, which will help us target the exact server.
