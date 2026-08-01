import { Controller, Get, Post, Body, UseGuards, Req } from '@nestjs/common';
import { AppService } from './app.service';
import { UsersService } from './users/users.service';
import { SalesService } from './sales/sales.service';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly usersService: UsersService,
    private readonly salesService: SalesService,
  ) {}

  @Post('register_user')
  async register(@Body() registrationDto: any) {
    return this.usersService.register(registrationDto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('register')
  async registerStaff(@Body() data: any, @Req() req: any) {
    const adminId = req.user.id;
    return this.usersService.registerStaff(data, adminId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('place_order')
  async placeOrder(@Body() orderData: any, @Req() req: any) {
    try {
      const user = req.user;
      return await this.salesService.placeOrder(orderData, user.id, user.role);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'An error occurred while placing the order';
      return {
        success: false,
        message: errorMessage,
      };
    }
  }
}
