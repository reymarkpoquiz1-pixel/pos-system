import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
  ) {}

  async create(data: Partial<Notification>) {
    const notification = this.notificationRepository.create(data);
    return await this.notificationRepository.save(notification);
  }

  async getLatestNotifications() {
    return this.notificationRepository.find({
      order: { createdAt: 'DESC' },
      take: 20,
    });
  }

  async markAsRead(id: number) {
    await this.notificationRepository.update(id, { isRead: true });
    return { success: true };
  }
}
