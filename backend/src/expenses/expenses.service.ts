import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Expense } from './entities/expense.entity';

@Injectable()
export class ExpensesService {
  constructor(
    @InjectRepository(Expense)
    private expenseRepository: Repository<Expense>,
  ) {}

  async findAll() {
    return await this.expenseRepository.find({
      order: { expenseDate: 'DESC' },
    });
  }

  async create(expenseData: any) {
    const expense = this.expenseRepository.create(expenseData);
    return await this.expenseRepository.save(expense);
  }
}
