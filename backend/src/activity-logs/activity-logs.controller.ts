import { Controller, Get } from '@nestjs/common';
import { ActivityLogsService } from './activity-logs.service';

@Controller('settings')
export class ActivityLogsController {
  constructor(private readonly activityLogsService: ActivityLogsService) {}

  @Get('get_activity_logs')
  async getActivityLogs() {
    const logs = await this.activityLogsService.getLatestLogs();
    return { success: true, logs };
  }
}
