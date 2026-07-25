import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

export enum ExpenseCategory {
  RENT = 'Rent',
  UTILITIES = 'Utilities',
  SALARY = 'Salary',
  INVENTORY = 'Inventory',
  OTHER = 'Other',
}

@Entity('expenses')
export class Expense {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @Column({
    type: 'enum',
    enum: ExpenseCategory,
    default: ExpenseCategory.OTHER,
  })
  category: ExpenseCategory;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: number;

  @Column({ name: 'expense_date', type: 'date' })
  expenseDate: string;
}
