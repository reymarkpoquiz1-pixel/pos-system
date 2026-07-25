import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Branch } from '../../branches/entities/branch.entity';

export enum ShiftStatus {
  OPEN = 'Open',
  CLOSED = 'Closed',
}

@Entity('shifts')
export class Shift {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @ManyToOne(() => Branch, (branch) => branch.shifts)
  @JoinColumn({ name: 'branch_id' })
  branch: Branch;

  @CreateDateColumn({ name: 'start_time' })
  startTime: Date;

  @Column({ name: 'end_time', nullable: true })
  endTime: Date;

  @Column({ name: 'starting_cash', type: 'decimal', precision: 10, scale: 2 })
  startingCash: number;

  @Column({ name: 'total_sales', type: 'decimal', precision: 10, scale: 2 })
  totalSales: number;

  @Column({ name: 'actual_cash', type: 'decimal', precision: 10, scale: 2 })
  actualCash: number;

  @Column({
    type: 'enum',
    enum: ShiftStatus,
    default: ShiftStatus.OPEN,
  })
  status: ShiftStatus;
}
