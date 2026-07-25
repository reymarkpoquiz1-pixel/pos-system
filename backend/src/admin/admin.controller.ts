import { Controller, Get } from '@nestjs/common';
import { AdminService } from './admin.service';

@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('get_initial_data')
  async getInitialData() {
    const data = await this.adminService.getInitialData();
    return {
      success: true,
      ...data,
    };
  }
}
