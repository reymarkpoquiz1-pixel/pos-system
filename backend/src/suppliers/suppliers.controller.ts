import { Controller, Get } from '@nestjs/common';
import { SuppliersService } from './suppliers.service';

@Controller('inventory')
export class SuppliersController {
  constructor(private readonly suppliersService: SuppliersService) {}

  @Get('get_suppliers')
  async getSuppliers() {
    const suppliers = await this.suppliersService.findAll();
    return { success: true, suppliers };
  }
}
