import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { NotificationsService } from '../notifications/notifications.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('settings')
export class SettingsController {
  constructor(
    private readonly settingsService: SettingsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  @Get('get_public_settings')
  async getPublicSettings() {
    const settings = await this.settingsService.getPublicSettings();
    return {
      success: true,
      settings: settings ? { ...settings, id: settings.id?.toString() } : null,
    };
  }

  @UseGuards(JwtAuthGuard)
  @Get('get_store_settings')
  async getStoreSettings() {
    const settings = await this.settingsService.getStoreSettings();
    return {
      success: true,
      settings: settings ? { ...settings, id: settings.id?.toString() } : null,
      user_settings: {
        is_2fa_enabled: 0,
      },
    };
  }

  @Get('backup_db')
  async backupDatabase() {
    const data = await this.settingsService.backupDatabase();
    return { success: true, data };
  }

  @Post('mark_read')
  markRead(@Body('id') id: number) {
    return this.notificationsService.markAsRead(id);
  }
}
