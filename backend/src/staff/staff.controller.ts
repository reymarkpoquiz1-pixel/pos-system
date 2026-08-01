import { Controller, Post, Get, Body, Req, UseInterceptors, UploadedFile } from '@nestjs/common';
import { StaffService } from './staff.service';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
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

  @Post('upload_profile_image')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  async uploadProfileImage(
    @UploadedFile() file: Express.Multer.File,
    @Body('user_id') userId: string,
    @Req() req: any,
  ) {
    const ip = req.ip || '0.0.0.0';
    return this.staffService.uploadProfileImage(+userId, file, ip);
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
