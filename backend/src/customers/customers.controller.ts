import { Controller, Get, Post, Body } from '@nestjs/common';
import { CustomersService } from './customers.service';

@Controller('costumers') // Compatibility with Flutter typo
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Get('get_customers')
  async getCustomers() {
    const customers = await this.customersService.findAll();
    return {
      success: true,
      customers,
    };
  }

  @Post('add_customer')
  async addCustomer(@Body() data: any) {
    return this.customersService.create(data);
  }
}
