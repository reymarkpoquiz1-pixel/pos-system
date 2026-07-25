import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { Shift } from '../../shifts/entities/shift.entity';
import { Sale } from '../../sales/entities/sale.entity';

@Entity('branches')
export class Branch {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  name: string;

  @Column({ nullable: true })
  address: string;

  @Column({ nullable: true })
  phone: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @OneToMany(() => Shift, (shift) => shift.branch)
  shifts: Shift[];

  @OneToMany(() => Sale, (sale) => sale.branch)
  sales: Sale[];
}
