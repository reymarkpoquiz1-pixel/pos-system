import { Controller, Get } from '@nestjs/common';
import { MarketingService } from './marketing.service';

@Controller('marketing')
export class MarketingController {
  constructor(private readonly marketingService: MarketingService) {}

  @Get('get_promos')
  async getPromos() {
    const promos = await this.marketingService.getAllPromos();
    return { success: true, promos };
  }

  @Get('get_vouchers')
  async getVouchers() {
    const vouchers = await this.marketingService.getAllVouchers();
    return { success: true, vouchers };
  }
}
