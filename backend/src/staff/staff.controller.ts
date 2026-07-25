import { Controller, Post, Get, Body, Req } from '@nestjs/common';
import { StaffService } from './staff.service';
import type { Request } from 'express';

@Controller('employees')
export class StaffController {
  constructor(private readonly staffService: StaffService) {}

  @Get('get_employees')
  async getEmployees() {
    const employees = await this.staffService.getEmployees();
    return {
      success: true,
      employees,
    };
  }

  @Post('update_staff')
  async updateStaff(@Body() data: any, @Req() req: any) {
    const ip = req.ip || '0.0.0.0';
    return this.staffService.updateStaff(data, ip);
  }

  @Post('delete_employees')
  async deleteEmployees(
    @Body() data: { user_id: number; admin_id: number },
    @Req() req: any,
  ) {
    const ip = req.ip || '0.0.0.0';
    return this.staffService.deleteStaff(data.user_id, data.admin_id, ip);
  }
}
