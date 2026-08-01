import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  Get,
  Query,
} from '@nestjs/common';
import { SalesService } from './sales.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('sales')
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

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

  @Get('get_shift_history')
  async getShiftHistory() {
    const shifts = await this.salesService.getShiftHistory();
    return { success: true, shifts };
  }

  @UseGuards(JwtAuthGuard)
  @Get('get_user_orders')
  async getUserOrders(@Query('user_id') userId: string) {
    const orders = await this.salesService.getUserOrders(+userId);
    return { success: true, orders };
  }
}
