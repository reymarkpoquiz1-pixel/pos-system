import { Controller, Get, Post, Body } from '@nestjs/common';
import { ExpensesService } from './expenses.service';

@Controller('reports')
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Get('get_expenses')
  async findAll() {
    const data = await this.expensesService.findAll();
    return { success: true, data };
  }

  @Post('add_expense')
  async create(@Body() expenseData: any) {
    const data = await this.expensesService.create(expenseData);
    return { success: true, data };
  }
}
