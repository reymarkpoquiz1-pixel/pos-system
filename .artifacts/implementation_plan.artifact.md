# Implementation Plan - Fix Magic Clean 404 Error

This plan addresses the "Server returned 404" error in the Magic Clean feature caused by API changes in the Hugging Face Gradio 4 environment.

## Proposed Changes

### Frontend Service

#### [MODIFY] [background_removal_service.dart](file:///C:/pos-all-in-one/frontend/lib/core/services/background_removal_service.dart)
- Update the endpoint discovery logic to try the new Gradio 4 paths.
- Add `/gradio_api/` prefix to the search list.
- Improve error logging to identify which exact URL is failing.

## Verification Plan

### Manual Verification
1. Run `sync_frontend.bat` locally.
2. Push changes to GitHub.
3. Test Magic Clean in the live browser.
