import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ActivityLog } from './entities/activity-log.entity';

@Injectable()
export class ActivityLogsService {
  constructor(
    @InjectRepository(ActivityLog)
    private readonly activityLogRepository: Repository<ActivityLog>,
  ) {}

  async log(
    userId: number | null,
    action: string,
    details: string,
    ip: string,
  ) {
    const logEntry = this.activityLogRepository.create({
      userId: userId ?? undefined,
      action,
      details,
      ipAddress: ip,
    });
    return await this.activityLogRepository.save(logEntry);
  }

  async getLatestLogs() {
    return await this.activityLogRepository.find({
      relations: { user: true },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }
}
